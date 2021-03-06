//
//  GameSettingsViewController.m
//  Matchismo
//
//  Created by Vasco Orey on 2/19/13.
//  Copyright (c) 2013 Delta Dog Studios. All rights reserved.
//

#import "GameSettingsViewController.h"
#import "GameSettings.h"
#import "AllGameSettings.h"

@interface GameSettingsViewController ()
@property (weak, nonatomic) IBOutlet UILabel *gameNameLabel;
@property (weak, nonatomic) IBOutlet UISlider *cardCountSlider;
@property (weak, nonatomic) IBOutlet UILabel *cardCountLabel;
@property (weak, nonatomic) IBOutlet UISwitch *shouldRedealSwitch;
@property (weak, nonatomic) IBOutlet UISegmentedControl *gameNameControl;
@property (weak, nonatomic) GameSettings *currentSettings;
@property (weak, nonatomic) IBOutlet UISlider *matchModeSlider;
@property (weak, nonatomic) IBOutlet UILabel *matchModeLabel;
@end

@implementation GameSettingsViewController

-(void)setup
{
    [self.view setBackgroundColor:[UIColor colorWithPatternImage:[UIImage imageNamed:@"background.png"]]];
}

-(void)awakeFromNib
{
    [self setup];
}

-(id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]))
    {
        [self setup];
    }
    return self;
}

-(void)viewDidLoad
{
    [super viewDidLoad];
    NSString *gameName = [self.gameNameControl titleForSegmentAtIndex:self.gameNameControl.selectedSegmentIndex];
    self.currentSettings = [AllGameSettings settingsForGame:gameName];
    [self updateUI];
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self updateUI];
}

-(void)updateUI
{
    NSString *gameName = [self.gameNameControl titleForSegmentAtIndex:self.gameNameControl.selectedSegmentIndex];
    self.gameNameLabel.text = gameName;
    self.cardCountSlider.value = (float)self.currentSettings.startingCardCount;
    self.cardCountLabel.text = [NSString stringWithFormat:@"%d", self.currentSettings.startingCardCount];
    self.matchModeSlider.value = (float)self.currentSettings.matchMode;
    self.matchModeLabel.text = [NSString stringWithFormat:@"%d", self.currentSettings.matchMode];
}

- (IBAction)cardCountSliderMoved:(UISlider *)sender {
    self.cardCountLabel.text = [NSString stringWithFormat:@"%d", (int)roundf(sender.value)];
}

- (IBAction)matchModeSliderMoved:(UISlider *)sender {
    self.matchModeLabel.text = [NSString stringWithFormat:@"%d", (int)roundf(sender.value)];
}

- (IBAction)gameNameControlChanged:(UISegmentedControl *)sender {
    NSString *gameName = [sender titleForSegmentAtIndex:sender.selectedSegmentIndex];
    self.currentSettings = [AllGameSettings settingsForGame:gameName];
    NSAssert(self.currentSettings, @"No settings found for %@", gameName);
    [self updateUI];
}

- (IBAction)enterPressed {
    // Save new settings
    self.currentSettings.startingCardCount = (int)roundf(self.cardCountSlider.value);
    self.currentSettings.matchMode = (int)roundf(self.matchModeSlider.value);
    [[[UIAlertView alloc] initWithTitle:@"OK" message:@"Settings updated!" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
}

- (IBAction)cancelPressed {
    [self updateUI];
}

@end
