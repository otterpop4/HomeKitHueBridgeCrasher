//
//  ViewController.m
//  HomeKitHueBridgeCrasher
//
//  Created by Brentt Blakkan on 10/10/16.
//  Copyright © 2016 Brentt Blakkan. All rights reserved.
//

#import "ViewController.h"
@import HomeKit;

@interface ViewController ()
{
    NSArray <HMCharacteristic *> *_characteristics;
    dispatch_once_t _setupCharacteristicsOnceToken;
}

@property (readonly, nonatomic) HMHomeManager *homeManager;
@property (readonly, nonatomic) NSArray <HMCharacteristic *> *characteristics;

@property (weak, nonatomic) IBOutlet UITextField *numberOfConcurrentConnectionsTextField;
@property (weak, nonatomic) IBOutlet UIButton *startButton;

@property (strong, nonatomic) NSDate *lastSuccessfulWrite;
@property (weak, nonatomic) IBOutlet UILabel *lastSuccessfulWriteLabel;

@end

@implementation ViewController

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        _homeManager = [[HMHomeManager alloc] init];
        self.homeManager.delegate = self;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self updateStartButtonEnabledState];
    self.lastSuccessfulWriteLabel.font = [UIFont monospacedDigitSystemFontOfSize:self.lastSuccessfulWriteLabel.font.pointSize weight:0.];
}

- (IBAction)start:(id)sender
{
    // start writing to characteristics in a loop
    for (HMCharacteristic *characteristic in self.characteristics) {
        [self loopRandomCharacteristicWriteForCharacteristic:characteristic];
    }
    [self.startButton setTitle:@"Writing..." forState:UIControlStateNormal];
    self.startButton.enabled = NO;
    self.numberOfConcurrentConnectionsTextField.enabled = NO;
    self.numberOfConcurrentConnectionsTextField.text = [NSString stringWithFormat:@"%lu", (unsigned long)[self.characteristics count]];
    
    [NSTimer scheduledTimerWithTimeInterval:.027 repeats:YES block:^(NSTimer * _Nonnull timer) {
        self.lastSuccessfulWriteLabel.text = [NSString stringWithFormat:@"%.2f seconds", -[self.lastSuccessfulWrite timeIntervalSinceNow]];
    }];
    
    // if no writes have succeeded for 5 seconds, log an error and re-start the looping writes
    [NSTimer scheduledTimerWithTimeInterval:15. repeats:YES block:^(NSTimer * _Nonnull timer) {
        NSTimeInterval timeSinceLastSuccessfulWrite = -[self.lastSuccessfulWrite timeIntervalSinceNow];
        if (timeSinceLastSuccessfulWrite > 15.) {
            NSLog(@"Have not completed a successful write for %f seconds. Re-starting writes.", timeSinceLastSuccessfulWrite);
            for (HMCharacteristic *characteristic in self.characteristics) {
                [self loopRandomCharacteristicWriteForCharacteristic:characteristic];
            }
        }
    }];
    
    self.lastSuccessfulWrite = [NSDate date];
}

- (void)loopRandomCharacteristicWriteForCharacteristic:(HMCharacteristic *)characteristic
{
    NSNumber *randomValue = [self randomValueForCharacteristicType:characteristic.characteristicType];
    NSLog(@"Writing to [%@:%@] - value: %@", characteristic.service.name,
          [self nameForCharacteristicType:characteristic.characteristicType], randomValue);
    
    [characteristic writeValue:randomValue completionHandler:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"Error writing to [%@:%@]: %@", characteristic.service.name, [self nameForCharacteristicType:characteristic.characteristicType], error);
        } else {
            self.lastSuccessfulWrite = [NSDate date];
            self.lastSuccessfulWriteLabel.text = @"0.00 seconds";
        }
        [self loopRandomCharacteristicWriteForCharacteristic:characteristic];
    }];
}

- (NSArray <HMCharacteristic *> *)characteristics
{
    if (self.homeManager.primaryHome != nil) {
        dispatch_once(&_setupCharacteristicsOnceToken, ^{
            NSMutableArray *characteristics = [NSMutableArray array];
            NSAssert(self.homeManager.primaryHome != nil, @"must have a primary home setup");
            
            for (HMAccessory *accessory in self.homeManager.primaryHome.accessories) {
                //DEBUG:
                if (![accessory.room.name isEqualToString:@"Living"]) {
                    //continue;
                }
                for (HMService *service in accessory.services) {
                    if ([service.serviceType isEqualToString:HMServiceTypeLightbulb]) {
                        for (HMCharacteristic *characteristic in service.characteristics) {
                            if ([characteristics count] >= self.numConcurrentCharacteristicWrites) {
                                break;
                            }
                            if ([characteristic.characteristicType isEqualToString:HMCharacteristicTypeHue]         ||
                                [characteristic.characteristicType isEqualToString:HMCharacteristicTypeSaturation]  ||
                                [characteristic.characteristicType isEqualToString:HMCharacteristicTypeBrightness]) {
                                [characteristics addObject:characteristic];
                            }

                        }
                    }
                }
            }
            
            _characteristics = [NSArray arrayWithArray:characteristics];
        });
    }
    
    return _characteristics;
}

- (NSNumber *)randomValueForCharacteristicType:(NSString *)characteristicType
{
    if ([characteristicType isEqualToString:HMCharacteristicTypeHue]) {
        return [NSNumber numberWithFloat:(((float)rand() / RAND_MAX) * 360.)];
    }
    if ([characteristicType isEqualToString:HMCharacteristicTypeSaturation]) {
        return [NSNumber numberWithFloat:(((float)rand() / RAND_MAX) * 100.)];
    }
    if ([characteristicType isEqualToString:HMCharacteristicTypeBrightness]) {
        return [NSNumber numberWithInt:(int)(((float)rand() / RAND_MAX) * 100)];
    }
    if ([characteristicType isEqualToString:HMCharacteristicTypePowerState]) {
        return [NSNumber numberWithBool:rand() % 2];
    }
    NSAssert(NO, @"unsupported characteristic type");
    return nil;
}

- (NSString *)nameForCharacteristicType:(NSString *)characteristicType
{
    if ([characteristicType isEqualToString:HMCharacteristicTypeHue]) {
        return @"Hue";
    }
    if ([characteristicType isEqualToString:HMCharacteristicTypeSaturation]) {
        return @"Saturation";
    }
    if ([characteristicType isEqualToString:HMCharacteristicTypeBrightness]) {
        return @"Brightness";
    }
    if ([characteristicType isEqualToString:HMCharacteristicTypePowerState]) {
        return @"Power State";
    }
    NSAssert(NO, @"unsupported characteristic type");
    return nil;
}

- (void)homeManagerDidUpdateHomes:(HMHomeManager *)manager
{
    NSAssert(self.homeManager.primaryHome != nil, @"must have a primary home setup");
    [self updateStartButtonEnabledState];
}

- (NSInteger)numConcurrentCharacteristicWrites
{
    return [self.numberOfConcurrentConnectionsTextField.text integerValue];
}

- (void)updateStartButtonEnabledState
{
    self.startButton.enabled = self.homeManager.primaryHome != nil && self.numConcurrentCharacteristicWrites > 0;
}

@end
