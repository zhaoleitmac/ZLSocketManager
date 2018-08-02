//
//  GMSocketManager.h
//  ZLSocketManager
//
//  Created by 赵雷 on 2018/6/7.
//  Copyright © 2018年 赵雷. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SMConstant.h"

@class GMSocketConnect;
@class GMCashierConnect;
@class GMSocketTask;

@interface GMSocketManager : NSObject

SM_SINGLETON_DECLARE

///UDP广播
- (GMSocketConnect *)creatUDPTask;

///TCP回话
- (GMSocketTask *)creatTask;

- (int)IDENTIFIER;

@end
