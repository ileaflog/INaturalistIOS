//
//  ImageStore.m
//  INaturalistIOS
//
//  Created by Ken-ichi Ueda on 2/20/12.
//  Copyright (c) 2012 iNaturalist. All rights reserved.
// 
//  Largely based on the ImageStore example in iOS Programming: The Big Nerd Range Guide, 
//  Second Edition by Joe Conway and Aaron Hillegass.
//

#import "ImageStore.h"

static ImageStore *sharedImageStore = nil;

@implementation ImageStore
@synthesize dictionary;

+ (id)allocWithZone:(NSZone *)zone
{
    return [self sharedImageStore];
}

+ (ImageStore *)sharedImageStore
{
    if (!sharedImageStore) {
        sharedImageStore = [[super allocWithZone:NULL] init];
    }
    return sharedImageStore;
}

- (id)init
{
    if (sharedImageStore) {
        return sharedImageStore;
    }
    self = [super init];
    if (self) {
        [self setDictionary:[[NSMutableDictionary alloc] init]];
        
        [NSNotificationCenter.defaultCenter addObserver:self 
                                               selector:@selector(clearCache:) 
                                                   name:UIApplicationDidReceiveMemoryWarningNotification 
                                                 object:nil];
    }
    return self;
}

- (UIImage *)find:(NSString *)key
{
    return [self find:key forSize:0];
}

- (UIImage *)find:(NSString *)key forSize:(int)size
{
    NSString *imgKey = [self keyForKey:key forSize:size];
    UIImage *image = [self.dictionary objectForKey:imgKey];
    if (!image) {
        image = [UIImage imageWithContentsOfFile:[self pathForKey:imgKey]];
        if (image) {
            [dictionary setValue:image forKey:imgKey];
        } else {
            NSLog(@"Error: couldn't find image file for %@", imgKey);
        }
    }
    return image;
}

- (void)store:(UIImage *)image forKey:(NSString *)key
{
    [self.dictionary setValue:image forKey:key];
    NSString *filePath = [self pathForKey:key];
    NSData *data = UIImageJPEGRepresentation(image, 0.8);
    [data writeToFile:filePath atomically:YES];
    
    // generate small
    [self generateSmallImageForKey:key];
    
    // generate square
    [self performSelectorInBackground:@selector(generateSquareImageForKey:) withObject:key];
}

- (void)generateSquareImageForKey:(NSString *)key
{
    UIImage *image = [self find:key];
    if (!image) {
        NSLog(@"Error: failed to generate square thumbnail for %@: image not in store.", key);
        return;
    }
    UIImage *squareImage = [ImageStore imageWithImage:image scaledToSizeWithSameAspectRatio:CGSizeMake(75, 75)];
    [self.dictionary setValue:squareImage forKey:[self keyForKey:key forSize:ImageStoreSquareSize]];
    NSString *filePath = [self pathForKey:key forSize:ImageStoreSquareSize];
    NSData *data = UIImageJPEGRepresentation(squareImage, 0.5);
    [data writeToFile:filePath atomically:YES];
}

- (void)generateSmallImageForKey:(NSString *)key
{
    UIImage *image = [self find:key];
    if (!image) {
        NSLog(@"Error: failed to generate small thumbnail for %@: image not in store.", key);
        return;
    }
    float smallWidth = image.size.width;
    float smallHeight = image.size.height;
    float max = MAX([UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height);
    float scaleFactor = max / MAX(smallWidth, smallHeight);
    if (smallWidth > smallHeight) {
        smallWidth = max;
        smallHeight = smallHeight * scaleFactor;
    } else {
        smallHeight = max;
        smallWidth = smallWidth * scaleFactor;
    }
    UIImage *smallImage = [ImageStore imageWithImage:image scaledToSizeWithSameAspectRatio:CGSizeMake(smallWidth, smallHeight)];
    
    [self.dictionary setValue:smallImage forKey:[self keyForKey:key forSize:ImageStoreSmallSize]];
    NSString *filePath = [self pathForKey:key forSize:ImageStoreSmallSize];
    NSData *data = UIImageJPEGRepresentation(smallImage, 0.5);
    [data writeToFile:filePath atomically:YES];
}

- (void)destroy:(NSString *)key
{
    if (!key) {
        return;
    }
    [self.dictionary removeObjectForKey:key];
    [[NSFileManager defaultManager] removeItemAtPath:[self pathForKey:key] error:NULL];
    
    [self.dictionary removeObjectForKey:[self keyForKey:key forSize:ImageStoreSmallSize]];
    [[NSFileManager defaultManager] removeItemAtPath:[self pathForKey:[self keyForKey:key forSize:ImageStoreSmallSize]] error:NULL];
    
    [self.dictionary removeObjectForKey:[self keyForKey:key forSize:ImageStoreSquareSize]];
    [[NSFileManager defaultManager] removeItemAtPath:[self pathForKey:[self keyForKey:key forSize:ImageStoreSquareSize]] error:NULL];
}

// http://stackoverflow.com/questions/8684551/generate-a-uuid-string-with-arc-enabled
- (NSString *)createKey
{
    CFUUIDRef uuid = CFUUIDCreate(NULL);
    NSString *uuidStr = (__bridge_transfer NSString *)CFUUIDCreateString(NULL, uuid);
    CFRelease(uuid);
    return uuidStr;
}

- (NSString *)pathForKey:(NSString *)key
{
    return [self pathForKey:key forSize:0];
}

- (NSString *)pathForKey:(NSString *)key forSize:(int)size
{
    NSArray *docDirs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *docDir = [docDirs objectAtIndex:0];
    NSString *photoDirPath = [docDir stringByAppendingPathComponent:@"photos"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:photoDirPath]) {
        NSError *error;
        [[NSFileManager defaultManager] createDirectoryAtPath:photoDirPath 
                                  withIntermediateDirectories:YES 
                                                   attributes:nil 
                                                        error:&error];
    }
    return [NSString stringWithFormat:@"%@.jpg", 
            [photoDirPath stringByAppendingPathComponent:
             [self keyForKey:key forSize:size]]];
}

- (NSString *)keyForKey:(NSString *)key forSize:(int)size
{
    NSString *str;
    switch (size) {
        case ImageStoreSquareSize:
            str = [NSString stringWithFormat:@"%@-square", key];
            break;
        case ImageStoreSmallSize:
            str = [NSString stringWithFormat:@"%@-small", key];
            break;
        default:
            str = key;
            break;
    }
    return str;
}

- (void)clearCache
{
    [dictionary removeAllObjects];
}

- (void)clearCache:(NSNotification *)note
{
    [self clearCache];
}

// Adapted from http://stackoverflow.com/questions/1282830/uiimagepickercontroller-uiimage-memory-and-more
// this code has numerous authors, please see stackoverflow for them all
+ (UIImage*)imageWithImage:(UIImage*)sourceImage scaledToSizeWithSameAspectRatio:(CGSize)targetSize
{  
    CGSize imageSize = sourceImage.size;
    CGFloat width = imageSize.width;
    CGFloat height = imageSize.height;
    CGFloat targetWidth = targetSize.width;
    CGFloat targetHeight = targetSize.height;
    CGFloat scaleFactor = 0.0;
    CGFloat scaledWidth = targetWidth;
    CGFloat scaledHeight = targetHeight;
    CGPoint thumbnailPoint = CGPointMake(0.0,0.0);
    
    if (CGSizeEqualToSize(imageSize, targetSize) == NO) {
        CGFloat widthFactor = targetWidth / width;
        CGFloat heightFactor = targetHeight / height;
        
        if (widthFactor > heightFactor) {
            scaleFactor = widthFactor; // scale to fit height
        }
        else {
            scaleFactor = heightFactor; // scale to fit width
        }
        
        scaledWidth  = width * scaleFactor;
        scaledHeight = height * scaleFactor;
        
        // center the image
        if (widthFactor > heightFactor) {
            thumbnailPoint.y = (targetHeight - scaledHeight) * 0.5; 
        }
        else if (widthFactor < heightFactor) {
            thumbnailPoint.x = (targetWidth - scaledWidth) * 0.5;
        }
    }     
    
    CGImageRef imageRef = [sourceImage CGImage];
    CGBitmapInfo bitmapInfo = CGImageGetBitmapInfo(imageRef);
    CGColorSpaceRef colorSpaceInfo = CGImageGetColorSpace(imageRef);
    
    if (bitmapInfo == kCGImageAlphaNone) {
        bitmapInfo = kCGImageAlphaNoneSkipLast;
    }
    
    CGContextRef bitmap;
    bitmap = CGBitmapContextCreate(NULL, targetWidth, targetHeight, CGImageGetBitsPerComponent(imageRef), CGImageGetBytesPerRow(imageRef), colorSpaceInfo, bitmapInfo);
    
    // In the right or left cases, we need to switch scaledWidth and scaledHeight,
    // and also the thumbnail point
    if (sourceImage.imageOrientation == UIImageOrientationLeft) {
        thumbnailPoint = CGPointMake(thumbnailPoint.y, thumbnailPoint.x);
        CGFloat oldScaledWidth = scaledWidth;
        scaledWidth = scaledHeight;
        scaledHeight = oldScaledWidth;
        
        CGContextRotateCTM (bitmap, radians(90));
        CGContextTranslateCTM (bitmap, 0, -scaledHeight);
        
    } else if (sourceImage.imageOrientation == UIImageOrientationRight) {
        thumbnailPoint = CGPointMake(thumbnailPoint.y, thumbnailPoint.x);
        CGFloat oldScaledWidth = scaledWidth;
        scaledWidth = scaledHeight;
        scaledHeight = oldScaledWidth;
        
        CGContextRotateCTM (bitmap, radians(-90));
        CGContextTranslateCTM (bitmap, -scaledWidth, 0);
        
    } else if (sourceImage.imageOrientation == UIImageOrientationUp) {
        // NOTHING
    } else if (sourceImage.imageOrientation == UIImageOrientationDown) {
        CGContextTranslateCTM (bitmap, targetWidth, targetHeight);
        CGContextRotateCTM (bitmap, radians(-180.));
    }
    
    CGContextDrawImage(bitmap, CGRectMake(thumbnailPoint.x, thumbnailPoint.y, scaledWidth, scaledHeight), imageRef);
    CGImageRef ref = CGBitmapContextCreateImage(bitmap);
    UIImage* newImage = [UIImage imageWithCGImage:ref];
    
    CGContextRelease(bitmap);
    CGImageRelease(ref);
    
    return newImage; 
}

@end