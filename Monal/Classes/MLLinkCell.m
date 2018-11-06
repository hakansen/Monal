//
//  MLLinkCell.m
//  Monal
//
//  Created by Anurodh Pokharel on 10/29/18.
//  Copyright © 2018 Monal.im. All rights reserved.
//

#import "MLLinkCell.h"
#import "UIImageView+WebCache.h"
@import SafariServices;


@implementation MLLinkCell

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
    self.bubbleView.layer.cornerRadius=16.0f;
    self.bubbleView.clipsToBounds=YES;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (NSString *) ogContentWithTag:(NSString *) tag inHTML:(NSString *) body
{
    NSRange titlePos = [body rangeOfString:tag];
    if(titlePos.location==NSNotFound) return nil;
    NSRange end = [body rangeOfString:@">" options:NSCaseInsensitiveSearch range:NSMakeRange(titlePos.location, body.length-titlePos.location)];
    NSString *subString = [body substringWithRange:NSMakeRange(titlePos.location, end.location-titlePos.location)];
    NSArray *parts = [subString componentsSeparatedByString:@"content="];
    NSString *text = parts.lastObject;
    if(text.length>2) {
        if([text characterAtIndex:text.length-1]=='/') {
         text = [text substringWithRange:NSMakeRange(0, text.length-1)];
        }
        text= [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        int trimLength=2;//quotes
        text = [text substringWithRange:NSMakeRange(1, text.length-trimLength)];
    }
    return [text stringByRemovingPercentEncoding];
}

-(void) openlink: (id) sender {
    
    if(self.link)
    {
        NSURL *url= [NSURL URLWithString:self.link];
        
        if ([url.scheme isEqualToString:@"http"] || [url.scheme isEqualToString:@"https"]) {
            SFSafariViewController *safariView = [[ SFSafariViewController alloc] initWithURL:url];
            [self.parent presentViewController:safariView animated:YES completion:nil];
        }
        
    }
}

-(void) loadPreviewWithCompletion:(void (^)(void))completion
{
    self.messageTitle.text=nil;
    self.imageUrl=@"";
    
    if(self.link) {
        /**
         <meta property="og:title" content="Nintendo recommits to “keep the business going” for 3DS">
         <meta property="og:image" content="https://cdn.arstechnica.net/wp-content/uploads/2016/09/3DS_SuperMarioMakerforNintendo3DS_char_01-760x380.jpg">
         facebookexternalhit/1.1
         */
        NSMutableURLRequest* request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:self.link]];
        [request setValue:@"facebookexternalhit/1.1" forHTTPHeaderField:@"User-Agent"]; //required on somesites for og tages e.g. youtube
        [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            
            NSString *body = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                self.messageTitle.text=[self ogContentWithTag:@"og:title" inHTML:body] ;
                self.imageUrl=[[self ogContentWithTag:@"og:image" inHTML:body] stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"];
                [self loadImageWithCompletion:^{
                    if(completion) completion();
                }];
            });
        }] resume];
    } else  if(completion) completion();
}

-(void) loadImageWithCompletion:(void (^)(void))completion
{
    if(self.imageUrl) {
        [self.previewImage sd_setImageWithURL:[NSURL URLWithString:self.imageUrl] completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, NSURL *imageURL) {
            if(error) {
                self.previewImage.image=nil;
            }
            
            if(completion) completion();
        }];
    } else  if(completion) completion();
}

@end