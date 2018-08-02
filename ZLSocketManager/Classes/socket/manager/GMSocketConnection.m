//
//  GMSocketConnection.m
//  ZLSocketManager
//
//  Created by 赵雷 on 2018/6/12.
//  Copyright © 2018年 赵雷. All rights reserved.
//

#import "GMSocketConnection.h"
#import "GCDAsyncSocket.h"
#import <libkern/OSAtomic.h>
#import <SystemConfiguration/CaptiveNetwork.h> // wifi库
#import "SMLog.h"
#import "GMSocketSessionMsg.h"
#import "GMSocketSessionManager.h"
#import "GMSocketUtil.h"

#define kSocketConnectionHeartBeatInterval 5

#define HBNoAckCountMax 7

#define kSocketHeartBeatTag 0

@interface GMSocketConnection () <GCDAsyncSocketDelegate>

@property (strong, nonatomic) dispatch_queue_t delegateQueue;

@property (nonatomic, strong) GCDAsyncSocket *socket;
///连接回调
@property (atomic,copy) void(^connectionResult)(GMSocketConnection *connection, NSError *);
///连接请求锁
@property (nonatomic, assign) OSSpinLock connectionLock;
///心跳计时器
@property (nonatomic, strong) NSTimer *heartBeatTimer;
//未收到心跳ACK就加1，直到7次未收到就重新连接
@property (nonatomic, assign) NSInteger HBNoAckCount;

@property (atomic, assign) NSInteger reconnectCount;

///数据处理同步锁
@property (nonatomic, strong) NSString *dataHandleLock;
///数据缓存区
@property (nonatomic, strong) NSMutableData *bufferData;

@end

@implementation GMSocketConnection

#pragma mark - getting

+ (NSString *)connectionIdWithHost:(NSString *)host
                             port:(int)port {
    return [NSString stringWithFormat:@"%@:%@", host, @(port)];
}


- (BOOL)isConnected {
    return self.socket.isConnected;
}
- (BOOL)isDisconnected {
    return self.socket.isDisconnected;
}

#pragma mark - construction method

-(instancetype)initWithHost:(NSString *)host
                       port:(int)port {
    if (self = [super init]) {
        _host = host;
        _port = port;
        self.delegateQueue = dispatch_queue_create("session.ZLSocketManager", DISPATCH_QUEUE_CONCURRENT);
        self.socket.delegate = self;
        self.connectionLock = OS_SPINLOCK_INIT;
        self.bufferData = [NSMutableData new]; // 存储接收数据的缓存区
        self.socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:_delegateQueue];
        self.dataHandleLock = @"cn.qncloud.socket.data";

    }
    return self;
}

#pragma mark - 心跳相关

///发送心跳
- (void)sendHeartBeat {
    if (self.isConnected) {
        SMDebugLog(@"========start heartbeat=======\r\nsocket host:%@\r\nsocket port:%i\r\n========================", self.host, self.port);
        GMSocketSessionHeader *header = [GMSocketSessionHeader heartbeatHeader];
        NSMutableData *sendData = [[NSMutableData alloc] init];
        NSData *extractedExpr = [GMSocketUtil messageHeaderTransToData:header];
        [sendData appendData:extractedExpr];
        [self.socket writeData:sendData withTimeout:-1 tag:kSocketHeartBeatTag];
    }
    if (self.HBNoAckCount >= HBNoAckCountMax && !self.isConnecting) {
        dispatch_async(dispatch_get_main_queue(), ^{
            //发送网络断开通知
//            [[NSNotificationCenter defaultCenter] postNotificationName:NotificationName.netStatusChanged object:nil userInfo:@{NotificationKey.netConnected : @(NO)}];
        });
        if ([self.delegate respondsToSelector:@selector(heatBeatDidDisconnect:)]) {
            [self.delegate heatBeatDidDisconnect:self];
        }
    }
    self.HBNoAckCount++;
}

///开启心跳
- (void)startConnectionHeartBeat {
    if (!_heartBeatTimer) {
        _heartBeatTimer = [NSTimer timerWithTimeInterval:kSocketConnectionHeartBeatInterval target:self selector:@selector(sendHeartBeat) userInfo:nil repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:_heartBeatTimer forMode:NSRunLoopCommonModes];
    }
}

///暂停心跳
- (void)stopConnectionHeartBeat {
    [self.heartBeatTimer invalidate];
    self.heartBeatTimer = nil;
}

#pragma mark - 连接/断开Socket

- (void)connection:(NSTimeInterval)timeout callback:(void(^)(GMSocketConnection *connection, NSError *))callback {
    OSSpinLock lock = self.connectionLock;
    BOOL locked = OSSpinLockTry(&lock);
    _isConnecting = YES;
    [self.socket disconnect];
    NSError *error = nil;
    BOOL result = [self.socket connectToHost:self.host onPort:self.port withTimeout:timeout error:&error];
    if (result && callback) {
        self.connectionResult = callback;
    }else {
        if (callback) {
            dispatch_async(dispatch_get_main_queue(), ^{
                callback(self, error);
            });
        }
    }
    if (locked) {
        OSSpinLockUnlock(&lock);
    }
}

- (void)connection:(void(^)(GMSocketConnection *connection, NSError *error))callback {
    [self connection:10 callback:callback];
}


- (void)disconnect {
    if (self.socket.isConnected) {
        [self.socket disconnectAfterReadingAndWriting];
    }
    [self stopConnectionHeartBeat]; //停止心跳
    self.bufferData = [NSMutableData new];//清空数据缓存
}

#pragma mark - 发送消息

- (void)sendMessage:(GMSocketSessionMsg *)message timeout:(NSTimeInterval)time tag:(int)tag {
    NSData *sendData = [self dataWithMessage:message];

    [self.socket writeData:sendData withTimeout:-1 tag:tag];
}

- (NSData *)dataWithMessage:(GMSocketSessionMsg *)message {
    NSMutableData *data = [[NSMutableData alloc] init];
    
    NSData *bodyData = [NSData data];
    if (message.body.DATA) {
        bodyData = message.body.DATA;
    }
    
    //8 表示消息体中除开消息DATA的字节数
    GMSocketSessionHeader *header = message.header;
    unsigned int bodyDataLenth;
    if(bodyData){
        bodyDataLenth = (unsigned int)bodyData.length + 8;
    }else{
        bodyDataLenth = 8;
    }
    header.LENGTH = bodyDataLenth;
    NSData *headerData = [GMSocketUtil messageHeaderTransToData:header];
    [data appendData:headerData];
    [data appendData:bodyData];
    return data;
}

#pragma mark - 处理接收消息

- (void)cleanDataBuffer {
    self.bufferData = [NSMutableData new];//清空数据缓存
}

///数据处理
- (void)handleData:(NSData *)data {
    @synchronized (self.dataHandleLock) {
        [self.bufferData appendData:data];
        [self handleBufferData];
    }
}

- (void)handleBufferData {
    if (self.bufferData.length >= 8) {//数据头已收齐
        Byte *dataByte = (Byte *)[self.bufferData bytes];
        int length = [GMSocketUtil analysisByteToInt:dataByte start:0 length:4];
        int realLength = length + 4;
        if (self.bufferData.length == realLength) {//收到完整数据包
            GMSocketSessionMsg *message = [GMSocketUtil transDataToMessage:self.bufferData messageLength:realLength];
            [self handleTheMessage:message];
            self.bufferData = [NSMutableData new];//清空数据缓存
        } else if (self.bufferData.length > realLength) {//超出完整数据包
            NSData *preData = [self.bufferData subdataWithRange:NSMakeRange(0, realLength)];
            NSData *sufData = [self.bufferData subdataWithRange:NSMakeRange(realLength, self.bufferData.length - realLength)];
            GMSocketSessionMsg *message = [GMSocketUtil transDataToMessage:preData messageLength:realLength];
            [self handleTheMessage:message];
            self.bufferData = [NSMutableData dataWithData:sufData];
            [self handleBufferData];
        }
    }
}

//消息回调
- (void)handleTheMessage:(GMSocketSessionMsg *)message {
    if (message.header.MSG_TYPE == 0) {//心跳回复包
        self.HBNoAckCount = 0;//把未收到心跳回复计数置0；
    } else {
        if (message.body.DATA.length) {
            if (message && [self.delegate respondsToSelector:@selector(handleMessage:connection:)]) {
                [self.delegate handleMessage:message connection:self];
            }
        }
    }
}

#pragma mark - GCDAsyncSocketDelegate

/**
 连接成功
 */
- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    _isConnecting = NO;
    SMDebugLog(@"========socket connected=======\r\nsocket host:%@\r\nsocket port:%i\r\n========================",self.host,self.port);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        //发送网络已连接通知
//        [[NSNotificationCenter defaultCenter] postNotificationName:NotificationName.netStatusChanged object:nil userInfo:@{NotificationKey.netConnected : @(YES)}];
        //执行连接网络回调
         if (self.connectionResult) {
            self.connectionResult(self, nil);
            self.connectionResult = nil;
         }
        //执行网络连接成功代理
        if ([self.delegate respondsToSelector:@selector(didConnect:)]) {
            [self.delegate didConnect:self];
        }
    });
    self.bufferData = [NSMutableData new];//清空数据缓存
    [self.socket readDataWithTimeout:-1 tag:99];
    [self startConnectionHeartBeat];
    self.HBNoAckCount = 0; //心跳回执未收到计数归0
    self.reconnectCount = 0;//重连次数归0
}

/**
 连接失败/断开连接
 */
- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    
    self.bufferData = [NSMutableData new];//清空数据缓存
    if (self.socket.isDisconnected) {
        if (self.reconnectCount >= 3) {
            _isConnecting = NO;
            SMDebugLog(@"========socket disconnected=======\r\nsocket host:%@\r\nsocket port:%i \r\n error:%@\r\n========================",self.host, self.port, err);
            dispatch_async(dispatch_get_main_queue(), ^{
                //发送网络断开通知
//                [[NSNotificationCenter defaultCenter] postNotificationName:NotificationName.netStatusChanged object:nil userInfo:@{NotificationKey.netConnected : @(NO)}];
                //执行连接网络回调
                if (self.connectionResult) {
                    self.connectionResult(self, [NSError errorWithDomain:@"连接网络失败" code:-1003 userInfo:nil]);
                    self.connectionResult = nil;
                }
                //执行网络连接失败代理
                if ([self.delegate respondsToSelector:@selector(didFailConnect:)]) {
                    [self.delegate didFailConnect:self];
                }
            });
            self.reconnectCount = 0;
        } else {
            self.reconnectCount++;
            if (self.isDisconnected) {
                [self connection:3 callback:self.connectionResult];
            }
        }
    }
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag {
    [sock readDataWithTimeout:-1 tag:tag];
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    [self handleData:data];
    [sock readDataWithTimeout:-1 tag:tag];
}

- (void)dealloc {
    SM_MEMORAY_CHECK_DEBUG_LOG;
}

@end


