//
//  main.m
//  ImageRead
//
//  Created by Eric Maciel on 06/10/23.
//

#import <Cocoa/Cocoa.h>
#import <Vision/Vision.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>
@end

@implementation AppDelegate {
    NSURL *baseURL;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    NSString *downloadsDir = NSSearchPathForDirectoriesInDomains(NSDownloadsDirectory, NSUserDomainMask, YES)[0];
    baseURL = [[NSURL alloc] initFileURLWithPath:downloadsDir];
}

- (void)application:(NSApplication *)application openURLs:(NSArray<NSURL *> *)urls {
    for (NSURL *fileURL in urls) {
        [self readFromImageFileURL:fileURL];
    }
}

- (void)readFromImageFileURL:(NSURL *)fileURL {
    if (!fileURL.isFileURL) {
        return;
    }
    NSImage *image = [[NSImage alloc] initWithContentsOfURL:fileURL];
    if (image) {
        [self processImage:image];
    }
}

- (void)processImage:(NSImage *)image {
    CGRect rect = {.origin = CGPointZero, .size = image.size};
    CGImageRef cgImage = [image CGImageForProposedRect:&rect context:nil hints:nil];
    if (cgImage == NULL) {
        return;
    }
    VNImageRequestHandler *requestHandler = [[VNImageRequestHandler alloc] initWithCGImage:cgImage options:@{}];
    VNRecognizeTextRequest *request = [[VNRecognizeTextRequest alloc] initWithCompletionHandler:^(VNRequest * _Nonnull request, NSError * _Nullable error) {
        NSMutableArray *recognizedStrings = [NSMutableArray array];
        NSMutableArray *rects = [NSMutableArray array];
        for (VNRecognizedTextObservation *observation in request.results) {
            NSString *string = [observation topCandidates:1].firstObject.string;
            [recognizedStrings addObject:string];
            CGRect rect = VNImageRectForNormalizedRect(observation.boundingBox, image.size.width, image.size.height);
            [rects addObject:[NSValue valueWithRect:rect]];
        }
        [self processStrings:recognizedStrings andRects:rects];
    }];
    request.recognitionLevel = VNRequestTextRecognitionLevelAccurate;
    request.usesLanguageCorrection = YES;
    [requestHandler performRequests:@[request] error:nil];
}

- (void)processStrings:(NSArray<NSString *> *)strings andRects:(NSArray<NSValue *> *)rects {
    NSMutableString *processedString = [NSMutableString string];
    CGRect prevRect = CGRectZero;
    for (NSInteger idx = 0; idx < strings.count; idx++) {
        NSString *string = strings[idx];
        CGRect rect = rects[idx].rectValue;
        if (CGRectEqualToRect(prevRect, CGRectZero)) {
            prevRect = rect;
        }
        if (rect.origin.y < prevRect.origin.y) {
            [processedString appendFormat:@"\n%@", string];
        } else {
            [processedString appendString:string];
        }
        prevRect = rect;
    }
    NSURL *destURL = [NSURL fileURLWithPath:[self newFileName] relativeToURL:baseURL];
    [self saveString:processedString to:destURL];
}

- (NSString *)newFileName {
    NSTimeInterval timestamp = [[NSDate date] timeIntervalSince1970];
    return [NSString stringWithFormat:@"ImageRead_%@.txt", @(timestamp)];
}

- (void)saveString:(NSString *)string to:(NSURL *)destURL {
    [string writeToURL:destURL atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        AppDelegate *appDelegate = [AppDelegate new];
        NSApplication *app = NSApplication.sharedApplication;
        app.delegate = appDelegate;
        [app run];
    }
    return EXIT_SUCCESS;
}
