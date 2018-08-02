//
//  GMSocketUtil.m
//  ZLSocketManager
//
//  Created by 赵雷 on 2018/6/14.
//  Copyright © 2018年 赵雷. All rights reserved.
//

#import "GMSocketUtil.h"
#import "GMSocketSessionMsg.h"

@implementation GMSocketUtil

+ (NSData *)dataWithMessage:(GMSocketSessionMsg *)message {
    NSMutableData *data = [[NSMutableData alloc] init];
    
    NSData *bodyData = [NSData data];
    if (message.body.DATA) {
        bodyData = message.body.DATA;
    }
    
    //10 表示消息体中除开消息DATA的字节数
    GMSocketSessionHeader *header = message.header;
    unsigned int bodyDataLenth;
    if(bodyData){
        bodyDataLenth = (unsigned int)bodyData.length + 8;
    }else{
        bodyDataLenth = 8;
    }
    header.LENGTH = bodyDataLenth;
    NSData *headerData = [self messageHeaderTransToData:header];
    [data appendData:headerData];
    [data appendData:bodyData];
    return data;
}

+ (NSData*)messageHeaderTransToData:(GMSocketSessionHeader *)header {
    NSMutableData *headerData =[[NSMutableData alloc] init];
    [headerData appendData:[self makeBytesWith:header.LENGTH andLength:4]];
    [headerData appendData:[self makeBytesWith:header.MSG_TYPE andLength:4]];
    [headerData appendData:[self makeBytesWith:header.IDENTIFIER andLength:4]];
    return headerData;
}

+ (GMSocketSessionMsg *)transDataToMessage:(NSData *)data messageLength:(NSInteger)length {
    if(data == nil){
        return nil;
    }
    GMSocketSessionMsg *message = [GMSocketSessionMsg new];
    GMSocketSessionHeader *header = [GMSocketSessionHeader new];
    GMSocketSessionBody *body = [GMSocketSessionBody new];
    Byte *dataByte = (Byte *)[data bytes];
    
    header.LENGTH = [self analysisByteToInt:dataByte start:0 length:4];
    header.MSG_TYPE = [self analysisByteToInt:dataByte start:4 length:4];
    header.IDENTIFIER = [self analysisByteToInt:dataByte start:8 length:4];
    message.header = header;
    
    if([data length]>12 && [data length]>=length && length>0){
        body.DATA = [data subdataWithRange:NSMakeRange(12, length - 12)];
    }
    
    message.body = body;
    return message;
    
}

+ (NSData*)makeBytesWith:(unsigned int)value andLength:(int) length{
    NSData *data;
    if(4 == length){
        Byte byte[4] = {};
        byte[0] =  (Byte) ((value>>24) & 0xFF);
        byte[1] =  (Byte) ((value>>16) & 0xFF);
        byte[2] =  (Byte) ((value>>8) & 0xFF);
        byte[3] =  (Byte) (value & 0xFF);
        data = [[NSData alloc] initWithBytes:byte length:4];
    }else{
        Byte byte[1] = {};
        byte[0] =(Byte) (value & 0xFF);
        data = [[NSData alloc] initWithBytes:byte length:1];
        
    }
    return data;
    
}


//解析响应的byte数组
+ (int)analysisByteToInt:(Byte[])originalByte start:(NSInteger)start length:(NSInteger)length {
    Byte *subByte = (Byte*)malloc(4);
    for (NSInteger i = start; i < start+length; i++){
        subByte[i-start] = originalByte[i];
    }
    return [self transByteToInt:subByte andLength:length];
}

+ (int)transByteToInt:(Byte[])byte andLength:(NSInteger)length{
    
    if(1 == length){
        unsigned int value = byte[0];
        byte[0] =  (Byte) ((value>>24) & 0xFF);
        byte[1] =  (Byte) ((value>>16) & 0xFF);
        byte[2] =  (Byte) ((value>>8) & 0xFF);
        byte[3] =  (Byte) (value & 0xFF);
    }
    NSData *subData = [[NSData alloc] initWithBytes:byte length:4];
    int datalength;
    [subData getBytes: &datalength length: sizeof(datalength)];
    
    int len = CFSwapInt32BigToHost(datalength);
    return len;
}

//+ (NSString*)analysisByteToStr:(Byte[])originalByte start:(NSInteger)start length:(NSInteger)length{
//    Byte *subByte = (Byte*)malloc(length);
//    for (NSInteger i = start; i < start+length; i++){
//        subByte[i-start] = originalByte[i];
//    }
//    return [self transByteToStr:subByte andLength:length];
//}
//
//+ (NSString*)transByteToStr:(Byte[])byte andLength:(NSInteger)length{
//    NSData* data = [NSData dataWithBytes: byte length:length];
//    return  [[NSString alloc] initWithData:[self UTF8Data:data] encoding:NSUTF8StringEncoding];
//}
//
///**
// 处理将NSData转为字符串的时候为nil
//
// */
//+ (NSData *)UTF8Data:(NSData*)data {
//    //保存结果
//    NSMutableData *resData = [[NSMutableData alloc] initWithCapacity:data.length];
//
//    NSData *replacement = [@"" dataUsingEncoding:NSUTF8StringEncoding];
//
//    uint64_t index = 0;
//    const uint8_t *bytes = data.bytes;
//
//    long dataLength = (long) data.length;
//
//    while (index < dataLength) {
//        uint8_t len = 0;
//        uint8_t firstChar = bytes[index];
//
//        // 1个字节
//        if ((firstChar & 0x80) == 0 && (firstChar == 0x09 || firstChar == 0x0A || firstChar == 0x0D || (0x20 <= firstChar && firstChar <= 0x7E))) {
//            len = 1;
//        }
//        // 2字节
//        else if ((firstChar & 0xE0) == 0xC0 && (0xC2 <= firstChar && firstChar <= 0xDF)) {
//            if (index + 1 < dataLength) {
//                uint8_t secondChar = bytes[index + 1];
//                if (0x80 <= secondChar && secondChar <= 0xBF) {
//                    len = 2;
//                }
//            }
//        }
//        // 3字节
//        else if ((firstChar & 0xF0) == 0xE0) {
//            if (index + 2 < dataLength) {
//                uint8_t secondChar = bytes[index + 1];
//                uint8_t thirdChar = bytes[index + 2];
//
//                if (firstChar == 0xE0 && (0xA0 <= secondChar && secondChar <= 0xBF) && (0x80 <= thirdChar && thirdChar <= 0xBF)) {
//                    len = 3;
//                } else if (((0xE1 <= firstChar && firstChar <= 0xEC) || firstChar == 0xEE || firstChar == 0xEF) && (0x80 <= secondChar && secondChar <= 0xBF) && (0x80 <= thirdChar && thirdChar <= 0xBF)) {
//                    len = 3;
//                } else if (firstChar == 0xED && (0x80 <= secondChar && secondChar <= 0x9F) && (0x80 <= thirdChar && thirdChar <= 0xBF)) {
//                    len = 3;
//                }
//            }
//        }
//        // 4字节
//        else if ((firstChar & 0xF8) == 0xF0) {
//            if (index + 3 < dataLength) {
//                uint8_t secondChar = bytes[index + 1];
//                uint8_t thirdChar = bytes[index + 2];
//                uint8_t fourthChar = bytes[index + 3];
//
//                if (firstChar == 0xF0) {
//                    if ((0x90 <= secondChar & secondChar <= 0xBF) && (0x80 <= thirdChar && thirdChar <= 0xBF) && (0x80 <= fourthChar && fourthChar <= 0xBF)) {
//                        len = 4;
//                    }
//                } else if ((0xF1 <= firstChar && firstChar <= 0xF3)) {
//                    if ((0x80 <= secondChar && secondChar <= 0xBF) && (0x80 <= thirdChar && thirdChar <= 0xBF) && (0x80 <= fourthChar && fourthChar <= 0xBF)) {
//                        len = 4;
//                    }
//                } else if (firstChar == 0xF3) {
//                    if ((0x80 <= secondChar && secondChar <= 0x8F) && (0x80 <= thirdChar && thirdChar <= 0xBF) && (0x80 <= fourthChar && fourthChar <= 0xBF)) {
//                        len = 4;
//                    }
//                }
//            }
//        }
//        // 5个字节
//        else if ((firstChar & 0xFC) == 0xF8) {
//            len = 0;
//        }
//        // 6个字节
//        else if ((firstChar & 0xFE) == 0xFC) {
//            len = 0;
//        }
//
//        if (len == 0) {
//            index++;
//            [resData appendData:replacement];
//        } else {
//            [resData appendBytes:bytes + index length:len];
//            index += len;
//        }
//    }
//
//    return resData;
//}

@end
