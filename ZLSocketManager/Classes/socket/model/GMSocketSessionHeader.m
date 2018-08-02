//
//  GMSocketSessionHeader.m
//  socketdemo
//
//  Created by vvipchen on 2018/6/8.
//  Copyright © 2018年 赵雷. All rights reserved.
//

#import "GMSocketSessionHeader.h"

@implementation GMSocketSessionHeader

+ (instancetype)heartbeatHeader {
    GMSocketSessionHeader *header = [GMSocketSessionHeader new];
    header.LENGTH = 8;
    header.MSG_TYPE = 0x00000001;
    header.IDENTIFIER = 0;
    return header;
}

+ (instancetype)searchCashierHeader {
    GMSocketSessionHeader *header = [GMSocketSessionHeader new];
    header.MSG_TYPE = 0x00000002;
    return header;
}

@end
