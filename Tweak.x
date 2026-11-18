#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface SPTPlayerTrack : NSObject
@property (nonatomic, readonly, copy) NSURL *URI;
@end

// Replace 'SPTNowPlayingViewController' if your Spotify version uses a different Now Playing class name
@interface SPTNowPlayingViewController : UIViewController <UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (nonatomic, strong) AVPlayer *customCanvasPlayer;
@property (nonatomic, strong) AVPlayerLayer *customCanvasLayer;
@property (nonatomic, strong) NSString *currentTrackID;
@end

%hook SPTNowPlayingViewController

%property (nonatomic, strong) AVPlayer *customCanvasPlayer;
%property (nonatomic, strong) AVPlayerLayer *customCanvasLayer;
%property (nonatomic, strong) NSString *currentTrackID;

- (void)viewDidLoad {
    %orig;
    [self setupCanvasAndGesture];
}

- (void)viewDidLayoutSubviews {
    %orig;
    if (self.customCanvasLayer) {
        self.customCanvasLayer.frame = self.view.bounds;
    }
}

- (void)updateWithTrack:(SPTPlayerTrack *)track {
    %orig;
    [self loadCanvasForTrack:track];
}

%new
- (void)setupCanvasAndGesture {
    // 1. Setup video player layer
    self.customCanvasPlayer = [[AVPlayer alloc] init];
    self.customCanvasPlayer.muted = YES;
    self.customCanvasPlayer.actionAtItemEnd = AVPlayerActionAtItemEndNone;

    self.customCanvasLayer = [AVPlayerLayer playerLayerWithPlayer:self.customCanvasPlayer];
    self.customCanvasLayer.frame = self.view.bounds;
    self.customCanvasLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.view.layer insertSublayer:self.customCanvasLayer atIndex:0];

    [[NSNotificationCenter defaultCenter] addObserverForName:AVPlayerItemDidPlayToEndTimeNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        if (note.object == self.customCanvasPlayer.currentItem) {
            [self.customCanvasPlayer seekToTime:kCMTimeZero];
            [self.customCanvasPlayer play];
        }
    }];

    // 2. Add a 1-second press-and-hold gesture to pick a video from Photos
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleCanvasLongPress:)];
    longPress.minimumPressDuration = 1.0;
    [self.view addGestureRecognizer:longPress];
}

%new
- (void)handleCanvasLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan || !self.currentTrackID) return;

    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.mediaTypes = @[UTTypeMovie.identifier];
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

%new
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey, id> *)info {
    NSURL *pickedURL = info[UIImagePickerControllerMediaURL];
    [picker dismissViewControllerAnimated:YES completion:nil];

    if (!pickedURL || !self.currentTrackID) return;

    // Save the chosen video to Documents/Canvases/<TRACK_ID>.mp4
    NSString *docsDir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    NSString *folderPath = [docsDir stringByAppendingPathComponent:@"Canvases"];
    [[NSFileManager defaultManager] createDirectoryAtPath:folderPath withIntermediateDirectories:YES attributes:nil error:nil];

    NSString *destPath = [NSString stringWithFormat:@"%@/%@.mp4", folderPath, self.currentTrackID];
    NSURL *destURL = [NSURL fileURLWithPath:destPath];

    [[NSFileManager defaultManager] removeItemAtURL:destURL error:nil];
    [[NSFileManager defaultManager] copyItemAtURL:pickedURL toURL:destURL error:nil];

    // Play immediately
    AVPlayerItem *newItem = [AVPlayerItem playerItemWithURL:destURL];
    [self.customCanvasPlayer replaceCurrentItemWithPlayerItem:newItem];
    self.customCanvasLayer.hidden = NO;
    [self.customCanvasPlayer play];
}

%new
- (void)loadCanvasForTrack:(SPTPlayerTrack *)track {
    if (!track || !track.URI) return;

    NSString *trackID = [track.URI.absoluteString componentsSeparatedByString:@":"].lastObject;
    if ([self.currentTrackID isEqualToString:trackID]) return;
    self.currentTrackID = trackID;

    NSString *docsDir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    NSString *videoPath = [NSString stringWithFormat:@"%@/Canvases/%@.mp4", docsDir, trackID];

    if ([[NSFileManager defaultManager] fileExistsAtPath:videoPath]) {
        AVPlayerItem *newItem = [AVPlayerItem playerItemWithURL:[NSURL fileURLWithPath:videoPath]];
        [self.customCanvasPlayer replaceCurrentItemWithPlayerItem:newItem];
        self.customCanvasLayer.hidden = NO;
        [self.customCanvasPlayer play];
    } else {
        [self.customCanvasPlayer pause];
        self.customCanvasLayer.hidden = YES;
    }
}

%end
