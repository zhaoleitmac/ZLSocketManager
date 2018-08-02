//
//  GMUDPSocketManager.m
//  ZLSocketManager
//
//  Created by 赵雷 on 2018/6/11.
//  Copyright © 2018年 赵雷. All rights reserved.
//

#import "GMUDPSocketManager.h"
#import "GCDAsyncUdpSocket.h"
#import "SMLog.h"
#import <libkern/OSAtomic.h>
#import "GMSocketSessionMsg.h"
#import "GMSocketManager.h"
#import "GMSocketConnection.h"
#import "GMSocketUtil.h"
#import "GMProtoBufSession.h"
#import "GMSessionError.h"

UInt16 const UDP_LOCAL_PORT = 2077;

UInt16 const UDP_CASHIER_PORT = 2088;

@interface GMUDPSocketManager () <GCDAsyncUdpSocketDelegate>

@property (strong, nonatomic) GCDAsyncUdpSocket *socket;

@property (strong, nonatomic) dispatch_queue_t delegateQueue;

@property (nonatomic, assign) OSSpinLock requestLock;

@property (nonatomic, strong) NSMutableSet <GMUDPSocketRequest *> *requestes;

@end

@implementation GMUDPSocketManager

+ (instancetype)sharedInstance {
    return [self new];
}

+ (instancetype)allocWithZone:(struct _NSZone *)zone {
    static id instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [super allocWithZone:zone];
    });
    return instance;
}

- (instancetype)init {
    static dispatch_once_t onceToken;
    static typeof(self) instance;
    dispatch_once(&onceToken, ^{
        instance = [super init];
        self.requestLock = OS_SPINLOCK_INIT;
        self.requestes = [NSMutableSet new];
        self.delegateQueue = dispatch_queue_create("UDP.ZLSocketManager", DISPATCH_QUEUE_CONCURRENT);
        [self setupSocket];
    });
    return instance;
}

- (void)setupSocket {
    if (!self.socket) {
        self.socket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:self.delegateQueue];
        NSError *error = nil;
        
        //绑定本地接收端口
        [self.socket bindToPort:UDP_LOCAL_PORT error:&error];
        if (error) {
            SMDebugLog(@"绑定本地接收端口失败，error: %@",error);
        }
        
        //启用广播
        [self.socket enableBroadcast:YES error:&error];
        if (error) {
            SMDebugLog(@"启用广播失败，error: %@",error);
        }
        
        //开始接收数据(不然会收不到数据)
        [self.socket beginReceiving:&error];
        if (error) {
            SMDebugLog(@"开启接受不了数据失败，error: %@",error);
        }
    }
}

- (void)sendRequestData:(__kindof GPBMessage *)requestData
                msgType:(int)msgType
                 toHost:(NSString *)host
                   port:(uint16_t)port
            withTimeout:(NSTimeInterval)timeout
               callback:(GMUDPCallback)callback {
    
    GMUDPSocketRequest *request = [GMUDPSocketRequest new];
    
    GMProtoBufSession *sessionInfo = [GMProtoBufSession sessionInfoWithRequestMsgType:msgType];
    request.sessionInfo = sessionInfo;
    request.requestData = requestData;
    request.callback = callback;
    
    request.timeOutTimer = [NSTimer timerWithTimeInterval:timeout target:self selector:@selector(timeoutAction:) userInfo:@{@"msgType" : @(msgType)} repeats:NO];
    
    [[NSRunLoop mainRunLoop] addTimer:request.timeOutTimer forMode:NSRunLoopCommonModes];

    OSSpinLock lock = self.requestLock;
    BOOL locked = OSSpinLockTry(&lock);
    [self.requestes addObject:request];
    if (locked) {
        OSSpinLockUnlock(&lock);
    }
    
    int IDENTIFIER = [GMSocketManager sharedInstance].IDENTIFIER;
    GMSocketSessionMsg *messageObj = [GMSocketSessionMsg messageWithIDENTIFIER:IDENTIFIER msgType:request.sessionInfo.REQUEST_MSG_TYPE messageData:request.requestData];
    NSData *data = [GMSocketUtil dataWithMessage:messageObj];

    //发送
    [self.socket sendData:data toHost:host port:port withTimeout:timeout tag:IDENTIFIER];
}

- (void)timeoutAction:(NSTimer *)timer {
    NSNumber *msgTypeN = timer.userInfo[@"msgType"];
    int msgType = msgTypeN.intValue;
    GMUDPSocketRequest *request = [self requestWithMsgType:msgType];
    dispatch_async(dispatch_get_main_queue(), ^{
        if (request.callback) {
            request.callback(nil, [NSError errorWithDomain:NSURLErrorDomain code:-1001 userInfo:@{@"msg" : @"连接超时"}]);
            request.callback = nil;
        }
        [self removeRequest:request];
    });
}

///删除request，并清空timer
- (void)removeRequest:(GMUDPSocketRequest *)request {
    OSSpinLock lock = self.requestLock;
    BOOL locked = OSSpinLockTry(&lock);
    [request.timeOutTimer invalidate];
    request.timeOutTimer = nil;
    if ([self.requestes containsObject:request]) {
        [self.requestes removeObject:request];
    }
    if (locked) {
        OSSpinLockUnlock(&lock);
    }
}

- (GMUDPSocketRequest *)requestWithResponseMsgType:(int)responseMsgType {
    GMUDPSocketRequest *currentRequest = nil;
    for (GMUDPSocketRequest *request in self.requestes) {
        if (request.sessionInfo.RESPONSE_MSG_TYPE == responseMsgType) {
            currentRequest = request;
            break;
        }
    }
    return currentRequest;
}

- (GMUDPSocketRequest *)requestWithMsgType:(int)msgType {
    GMUDPSocketRequest *currentRequest = nil;
    for (GMUDPSocketRequest *request in self.requestes) {
        if (request.sessionInfo.REQUEST_MSG_TYPE == msgType) {
            currentRequest = request;
            break;
        }
    }
    return currentRequest;
}

- (void)handleData:(NSData *)data {
    Byte *dataByte = (Byte *)[data bytes];
    int length = [GMSocketUtil analysisByteToInt:dataByte start:0 length:4];
    int realLength = length + 4;
    GMSocketSessionMsg *msg = [GMSocketUtil transDataToMessage:data messageLength:realLength];
    
    GMUDPSocketRequest *request = [self requestWithResponseMsgType:msg.header.MSG_TYPE];
    id responseObj = nil;
    NSError *error = nil;
    if (data.length) {
        Class responseClass = NSClassFromString(request.sessionInfo.responseClassName);
        SEL selector = @selector(parseFromData:error:);
        if ([responseClass respondsToSelector:selector]) {
            responseObj = [responseClass performSelector:selector withObject:msg.body.DATA withObject:nil];
            
            SEL errorSelector = @selector(returnCode);
            if ([responseObj respondsToSelector:errorSelector]) {//匹配错误信息
                int returnCode = [responseObj performSelector:errorSelector];
                NSString *returnMsg = [GMSessionError errorMsgWithErrorCode:returnCode];
                if (returnMsg.length) {
                    error = [NSError errorWithDomain:returnMsg code:returnCode userInfo:nil];
                }
            }
        }
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (request.callback) {
            request.callback(responseObj, error);
            request.callback = nil;
        }
        [self removeRequest:request];
    });
}

#pragma mark - GCDAsyncUdpSocketDelegate

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data fromAddress:(NSData *)address withFilterContext:(id)filterContext{
    
    NSString *ip = [GCDAsyncUdpSocket hostFromAddress:address];

    SMDebugLog(@"收到来自%@的UDP消息", ip);
    [self handleData:data];
}


- (void)udpSocket:(GCDAsyncUdpSocket *)sock didNotSendDataWithTag:(long)tag dueToError:(NSError *)error {
    
    GMUDPSocketRequest *request = [self requestWithMsgType:(int)tag];
    dispatch_async(dispatch_get_main_queue(), ^{
        if (request.callback) {
            request.callback(nil, error);
            request.callback = nil;
        }
        [self removeRequest:request];
    });
    SMDebugLog(@"%ld消息发送失败", tag);
}

@end

@implementation GMUDPSocketRequest

@end
