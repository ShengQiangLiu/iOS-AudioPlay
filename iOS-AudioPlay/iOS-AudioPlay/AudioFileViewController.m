//
//  AudioFileViewController.m
//  iOS-AudioPlay
//
//  Created by admin on 16/1/23.
//  Copyright © 2016年 ShengQiangLiu. All rights reserved.
//

#import "AudioFileViewController.h"
#import "EQAudioFile.h"

@interface AudioFileViewController ()
{
@private
    EQAudioFile *_audioFile;
}
@end

@implementation AudioFileViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    NSString *path = [[NSBundle mainBundle] pathForResource:@"MP3Sample" ofType:@"mp3"];
    _audioFile = [[EQAudioFile alloc] initWithFilePath:path fileType:kAudioFileMP3Type];
    BOOL isEof = NO;
    while (!isEof)
    {
        NSArray *parsedData = [_audioFile parseData:&isEof];
        NSLog(@"%lu data parsed, should be filled in buffer.",(unsigned long)parsedData.count);
    }
    
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
