#import "VideoCompressorPlugin.h"
#if __has_include(<video_compressor/video_compressor-Swift.h>)
#import <video_compressor/video_compressor-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "video_compressor-Swift.h"
#endif

@implementation VideoCompressorPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftVideoCompressorPlugin registerWithRegistrar:registrar];
}
@end
