//
//  GMUDPSocketManager.h
//  ZLSocketManager
//
//  Created by 赵雷 on 2018/6/11.
//  Copyright © 2018年 赵雷. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SMConstant.h"

@class GPBMessage;
@class GMProtoBufSession;

FOUNDATION_EXTERN UInt16 const UDP_LOCAL_PORT;

FOUNDATION_EXTERN UInt16 const UDP_CASHIER_PORT;

///成功回调
typedef void(^GMUDPCallback)(NSDictionary *d, NSError *e);

@interface GMUDPSocketManager : NSObject

SM_SINGLETON_DECLARE

- (void)sendRequestData:(__kindof GPBMessage *)requestData
                msgType:(int)msgType
                 toHost:(NSString *)host
                   port:(uint16_t)port
            withTimeout:(NSTimeInterval)timeout
               callback:(GMUDPCallback)callback;

@end

@interface  GMUDPSocketRequest : NSObject

@property (nonatomic, strong) __kindof GPBMessage *requestData;

@property (nonatomic, strong) GMProtoBufSession *sessionInfo;

@property (nonatomic, strong) NSTimer *timeOutTimer;

@property (nonatomic, copy) GMUDPCallback callback;

@end
