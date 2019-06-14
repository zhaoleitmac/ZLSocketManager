# ZLSocketManager
该示例是基于Protobuf数据协议的利用链式语法对CocoaAsyncSocket进行的二次封装。
## Requirements

- iOS 8.0 or later

## How to use

### UDP连接
```objective-c
__kindof GPBMessage *requestObj = [GPBMessage new];
//config gpbObj
[[GMSocketManager sharedInstance] creatConnect]
.IP(severIP.copy)
.requestData(requestObj)
.success(^(__kindof GPBMessage responseObj) {
    callback(response, YES);
})
.error(^(NSError *error) {
    callback(nil, NO);
})
.send();
```

### TCP连接
```objective-c
__kindof GPBMessage *requestObj = [GPBMessage new];
//config gpbObj
int MSG_TYPE = 1;
[[GMSocketManager sharedInstance] creatTask]
.requestData(requestObj)
.timeout(20)
.msgType(MSG_TYPE)
.success(^(__kindof GPBMessage responseObj) {
    callback(response, nil);
})
.error(^(NSError *error) {
    callback(nil, error);
})
.excuteNeedLogin(NO);
```

### MsgType
MSG_TYPE是区分会话（接口）Type，例如登录、获取用户信息等。  
PBMessageInfo.plist中存有以MsgType为Key的Dictionary，Dictionary中RESPONSE_MSG_TYPE是服务端的回复Type(客户端暂无用)，responseClassName为回复消息的类名（GPBMessage的子类）。  
开发者需自己配置该文件，程序根据配置自动转出实例作为success回调参数，并调用success回调。
### ErrorCode的处理
每个消息GPBMessage类都必须包含一个returnCode（名称可配置）成员变量（属性）。  
GMSessionErrorMap.plist保存所有的错误code和其对应错误msg。  
开发者需自己配置该文件，程序根据配置自动识别错误作为error回调参数，并调用error回调。
