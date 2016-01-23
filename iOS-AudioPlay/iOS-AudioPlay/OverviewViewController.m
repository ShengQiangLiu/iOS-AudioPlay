//
//  OverviewViewController.m
//  iOS-AudioPlay
//
//  Created by admin on 16/1/22.
//  Copyright © 2016年 ShengQiangLiu. All rights reserved.
//

#import "OverviewViewController.h"

@interface OverviewViewController ()
@property (weak, nonatomic) IBOutlet UIWebView *webView;

@end

@implementation OverviewViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://msching.github.io/blog/2014/07/07/audio-in-ios/"]];
    [self.webView loadRequest:request];
    
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
