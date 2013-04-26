//
//  CellularSoundsViewController.m
//  Cellular-Sounds
//
//  Created by Vasco Orey on 4/23/13.
//  Copyright (c) 2013 Delta Dog Studios. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>

#import "CellularSoundsViewController.h"
#import "GridView.h"
#import "PoolOfLife.h"
//MIDI
#import "BMidiManager.h"
#import "BSequence.h"
#import "BNoteEventHandler.h"
#import "BSequencePlayer.h"
#import "BMidiClock.h"
#import "AudioManager.h"
#import "BMidiNote.h"
//WTS
#import "AQSound.h"

@interface CellularSoundsViewController () <GridViewDelegate, PoolOfLifeDelegate, BNoteEventHandler, BTempoEventHandler>
{
    NSCondition *_shouldUpdateGrid;
}
//Outlets
@property (weak, nonatomic) IBOutlet UILabel *metronomeLabel;
@property (weak, nonatomic) IBOutlet UILabel *currentSpeciesLabel;
@property (weak, nonatomic) IBOutlet GridView *gridView;
//MIDI
@property (nonatomic, strong) BSequencePlayer *sequencePlayer;
@property (nonatomic, strong) BMidiClock *midiClock;
@property (nonatomic, strong) AudioManager *audioManager;
@property (nonatomic, strong) NSThread *audioThread;
@property (nonatomic) NSUInteger metronomeTicks;
//Access this property using @synchronized(self.sequence) as it's being used 
@property (nonatomic, strong) NSMutableArray *sequence;
@property (nonatomic, strong) NSMutableArray *completeSong;
@property (nonatomic) NSInteger timeForNextUpdate;
@property (nonatomic) NSInteger startTimeForNextBar;
//WTS
@property (nonatomic, strong) AQSound *sound;
//Model
@property (nonatomic, strong) PoolOfLife *pool;
@property (nonatomic) NSUInteger numRows;
@property (nonatomic) NSUInteger numCols;
@property (nonatomic) PoolOfLifeGameMode gameMode;
@property (nonatomic) NSInteger currentSpecies;
@property (nonatomic, strong) NSThread *poolUpdateThread;
@property (nonatomic) BOOL updatePool;
@property (nonatomic) NSInteger updateTime;
//Control
@property (nonatomic, getter = isPlaying) BOOL playing;
@property (nonatomic, strong) CADisplayLink *displayLink;
@end

@implementation CellularSoundsViewController

#pragma mark - View Lifecycle

-(void)setup
{
    //Perform setup that has to go before viewDidLoad
    self.numCols = 21;
    self.numRows = 16;
    self.currentSpecies = 1;
    self.gameMode = PoolOfLifeGameModeConway;
    self.playing = YES;
    [self setupSound];
    _shouldUpdateGrid = [[NSCondition alloc] init];
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        [self setup];
    }
    return self;
}

-(void)awakeFromNib
{
    [self setup];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.gridView.delegate = self;
}

-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    self.gridView.delegate = nil;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Properties - Lazy Instantiation

-(PoolOfLife *)pool
{
    if(!_pool)
    {
        _pool = [[PoolOfLife alloc] initWithRows:self.numRows cols:self.numCols gameMode:self.gameMode];
        _pool.delegate = self;
    }
    return _pool;
}

-(NSMutableArray *)completeSong
{
    if(!_completeSong)
    {
        _completeSong = [[NSMutableArray alloc] init];
    }
    return _completeSong;
}

#pragma mark - GridView Delegate

-(void)didDetectTouchAtRow:(NSInteger)row col:(NSInteger)col started:(BOOL)started
{
    //NSLog(@"%d,%d, %d", col, row, started);
    [self.pool flipCellAtRow:row col:col started:started species:self.currentSpecies];
}

#pragma mark - PoolOfLife Delegate

-(void)didActivateCellAtRow:(NSInteger)row col:(NSInteger)col species:(NSInteger)species
{
    [self.gridView activateRow:row col:col color:species];
}

#pragma mark - IBActions

- (IBAction)startStop:(UIButton *)sender {
    if(!self.isPlaying)
    {
        [self.midiClock resume];
        [self.audioManager setVolume:1];
        [sender setTitle:@"Pause" forState:UIControlStateNormal];
        self.playing = YES;
        [self.sound start];
    }
    else {
        self.playing = NO;
        [self.midiClock pause];
        [self.audioManager setVolume:0];
        [sender setTitle:@"Resume" forState:UIControlStateNormal];
        [self.sound stop];
    }
}

- (IBAction)reset {
    [self.pool reset];
    self.gridView.grid = self.pool.state;
    @synchronized(self.sequence)
    {
        [self.sequence removeAllObjects];
    }
}

- (IBAction)changeCurrentSpecies:(UIButton *)sender {
    self.currentSpecies = sender.tag;
    NSString *text;
    switch (sender.tag) {
        case 1:
            text = @"Blue";
            break;
        case 2:
            text = @"Green";
            break;
        case 3:
            text = @"Yellow";
            break;
        case 4:
            text = @"Red";
            break;
        default:
            break;
    }
    self.currentSpeciesLabel.text = text;
    self.currentSpeciesLabel.textColor = sender.backgroundColor;
}

- (IBAction)changeGameMode:(UISwitch *)sender {
    self.pool.gameMode = sender.isOn ? PoolOfLifeGameModeConway : PoolOfLifeGameModeNone;
}

#pragma mark - MIDI-Library

// What to do when a new note is activated - be very careful!! We're
// multi-threading
-(void) handleNoteEvent:(BMidiNote *)note {
    // Play the note in the audio manager
    [self.audioManager playNote:note];
    //NSLog(@"Note: %d, Channel: %d, Velocity: %d, Start: %d, Duration: %d", note.note, note.channel, note.velocity, [note getStartTime], [note getDuration]);
    //[self.sound triggerMidiNoteAtFirstAvailableVoice:note.note velocity:127];
}

// Handle any tempo events which occur
-(void) handleTempoEvent:(BTempoEvent *)tempoEvent {
    // Set the midi clock PPNQ
    if(tempoEvent.type == BPPNQ) {
        self.midiClock.PPQN = tempoEvent.PPNQ;
        NSLog(@"Set PPQN: %i", tempoEvent.PPNQ);
    }
    // Set the midi clock BPM
    if (tempoEvent.type == BTempo) {
        self.midiClock.BPM = tempoEvent.BPM;
        NSLog(@"Set BPM: %f", tempoEvent.BPM);
    }
    
    // Set the metronome rate
    if (tempoEvent.type == BTimeSignature) {
        // Set metronome rate. The metronome figure is measured as a fraction
        // over 24. So, a value of 24 means once per quarter note. 12 means
        // once every 1/8 note etc...
        float metronomeRate = (float) tempoEvent.ticksPerQtr / 24.0;
        // Work out how many pulses this represents
        self.midiClock.metronomeFreq = (int) roundf(metronomeRate * self.midiClock.PPQN);
        
    }
}

-(void) setupSound
{
//    // Create a new midi manager and load our midi file
//    BMidiManager * midiManager = [BMidiManager new];
//    
//    // The process midi file will return a our sequence of MIDI events
//    BSequence * sequence = [midiManager processMidiFile:@"dancing_queen"];
//    
//    // Initialise a new sequence player - this will actually play our
//    // midi sequence
//    self.sequencePlayer = [BSequencePlayer new];
//    
//    // Add the sequence to the sequence player
//    self.sequencePlayer.sequence = sequence;
//    
//    // Add this class as a note processor - this means that notes will
//    // be delivered to the addNote method of this class in realtime to
//    // be handled
//    [self.sequencePlayer setNoteHandler:self];
//    [self.sequencePlayer setTempoHandler:self];
    
    // Create a new midi clock - this keeps track of MIDI time based on
    // midi properties such as BPM
    self.midiClock = [BMidiClock new];
    self.midiClock.tickResolution = 1;
    
    self.sound = [[AQSound alloc] init];
    [self.sound newAQ];
    [self.sound start];
    
    // Create a new audio manager this will vocalize the midi messages
    self.audioManager = [AudioManager newAudioManager];
    
    // Load the default general midi instruments from the midi file
    [self.audioManager configureForGeneralMidi:@"fluid_gm"];
    
    // Enable percussion
    [self.audioManager enablePercussion:@"fluid_gm" withPatch:0 withVolume:1];
    
    // Add a silent default
    [self.audioManager addDefaultVoice:@"fluid_gm" withPatch:0 withVolume:1];
    
    // Start the audio manager. After the audio manager has started you can't add any more
    // voices
    [self.audioManager startAudioGraph];
    
    // Create the audio thread. This is a high priority thread
    // which will update the audio around 400 times per second
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        [self audioLoop];
    });
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        [self poolLoop];
    });
    [_shouldUpdateGrid lock];
    [_shouldUpdateGrid signal];
    [_shouldUpdateGrid unlock];
}

#pragma mark - Update Methods

-(void) audioLoop {
    // Loop until the program terminates
    while (true) {
        
        // Update the midi clock every loop
        [self.midiClock update];
        
        // Only check for events if the required number of ticks
        // has elapsed - determined by _midiClock.tickResolution
        NSInteger discreteTime = [self.midiClock getDiscreteTime];
        if([self.midiClock requiredTicksElapsed]) {
            //[self.sequencePlayer update:[self.midiClock getDiscreteTime]];
            [self updateSequence:discreteTime];
            [self.audioManager update:discreteTime];
            
            // We need to check if the metronome has ticked from within the
            // audio loop because it might be missed by the slower render loop
            if([self.midiClock isMetronomeTick]) {
                self.metronomeTicks ++;
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.metronomeLabel.text = [NSString stringWithFormat:@"%d", (self.metronomeTicks % 4) + 1];
                    if(self.metronomeTicks % 4 == 0)
                    {
                        NSLog(@"Setting the new grid (%d ticks)", self.metronomeTicks);
                        self.gridView.grid = self.pool.state;
                    }
                });
            }
        }
        //Always perform the update on the last sixteenth note
        if((self.timeForNextUpdate - (self.midiClock.PPQN / 4)) < discreteTime)
        {
            [_shouldUpdateGrid lock];
            [_shouldUpdateGrid signal];
            [_shouldUpdateGrid unlock];
            self.updateTime = discreteTime;
            //Each row is a 16th note
            self.timeForNextUpdate += (self.midiClock.PPQN / 4) * self.numRows;
        }
    }
}

// Play the next notes in the sequence
-(void) updateSequence: (NSInteger) timeInPulses{
    
    // Other pointers we setup to improve efficiency
    BMidiEvent * midiEvent;
    NSMutableArray *toDelete = [[NSMutableArray alloc] init];
    NSMutableArray *sequence;
    @synchronized(self.sequence)
    {
        sequence = [self.sequence mutableCopy];
    }
    NSUInteger count = [sequence count];
    // Loop over sequence and work out if the note should be played
    for(int j=0; j<count; j++) {
        
        // Get a pointer to the current event
        midiEvent = sequence[j];
        
        // If the time is greater than the current time then skip the note
        // and add one to the relaxation counter
        if([midiEvent getStartTime] > timeInPulses) {
            continue;
        }
        
        // Add the note for deleting
        [toDelete addObject:midiEvent];
        [self.completeSong addObject:midiEvent];
        
        if(midiEvent.eventType == Note) {
            [self handleNoteEvent:(BMidiNote *) midiEvent];
        }
        else if(midiEvent.eventType == Tempo ) {
            [self handleTempoEvent:(BTempoEvent *) midiEvent];
        }
    }
    
    // Clean up by deleting used notes
    [sequence removeObjectsInArray:toDelete];
    @synchronized(self.sequence)
    {
        self.sequence = sequence;
    }
}

-(void)poolLoop
{
    while(true)
    {
        //Wait for a signal from the audioloop.
        NSLog(@"%g: waiting...", CACurrentMediaTime());
        [_shouldUpdateGrid lock];
        [_shouldUpdateGrid wait];
        NSLog(@"%g: working!", CACurrentMediaTime());
        [self.pool performStep];
        NSArray *currentGrid = self.pool.state;
        NSInteger startTime = self.startTimeForNextBar;
        if(!startTime)
        {
            startTime = self.updateTime;
            self.startTimeForNextBar = startTime;
        }
        NSInteger beatDuration = self.midiClock.PPQN / 4;
        NSInteger channel = 0;
        NSMutableDictionary *notes = [[NSMutableDictionary alloc] init];
        NSMutableArray *finalNotes = [[NSMutableArray alloc] init];
        for(int row = 0; row < self.numRows; row ++)
        {
            for(int col = 0; col < self.numCols; col ++)
            {
                NSNumber *currentCol = @(col);
                NSInteger dt = row * beatDuration;
                if([[notes allKeys] containsObject:currentCol])
                {
                    if([currentGrid[row][col] intValue])
                    {
                        //Update the note in the dictionary
                        BMidiNote *note = notes[currentCol];
                        [note setDuration:([note getDuration] + beatDuration)];
                    }
                    else
                    {
                        //Remove the note from the dictionary and insert it into finalNotes
                        BMidiNote *noteToAdd = notes[currentCol];
//                        BMidiNote *noteOff = [[BMidiNote alloc] init];
//                        noteOff.note = noteToAdd.note;
//                        noteOff.channel = 0;
//                        noteOff.velocity = 0;
//                        [noteOff setStartTime:[noteToAdd getStartTime] + [noteToAdd getDuration]];
//                        [finalNotes addObject:noteOff];
                        [finalNotes addObject:noteToAdd];
                        [notes removeObjectForKey:currentCol];
                    }
                }
                else
                {
                    if((channel = [currentGrid[row][col] intValue]))
                    {
                        //Create a new note and insert it into the dictionary
                        BMidiNote *note = [[BMidiNote alloc] init];
                        note.channel = (channel - 1);
                        note.velocity = 127;
                        note.note = [self convertToMidi:col];
                        [note setStartTime:(startTime + dt)];
                        [note setDuration:beatDuration];
                        notes[currentCol] = note;
                    }
                }
            }
        }
        [finalNotes addObjectsFromArray:[notes allValues]];
        NSInteger deltaTime = self.numRows * (self.midiClock.PPQN / 4);
        self.startTimeForNextBar += deltaTime;
        @synchronized(self.sequence)
        {
            self.sequence = finalNotes;
        }
        [_shouldUpdateGrid unlock];
    }
}

//C3 = 36, D = 38, E = 40, F = 41, G = 43, A = 45, B = 47
#define C_MAJ_NOTES @[@(36), @(38), @(40), @(41), @(43), @(45), @(47)]
//C D E G A C
#define C_PENT_MAJ_NOTES @[@(24), @(26), @(28), @(31), @(33), @(36)]
//A C D E G A
#define A_PENT_MIN_NOTES @[@(21), @(24), @(26), @(28), @(31), @(33)]
//Arpeggios
//C - E - G, D - F - A, E - G - B
#define C_MAJ_ARPEGGIOS @[@(24), @(28), @(31), /**/ @(26), @(29), @(33), /**/ @(28), @(31), @(35)]

// http://www.midimountain.com/midi/midi_note_numbers.html
-(int)convertToMidi:(int)note
{
    NSInteger count = [A_PENT_MIN_NOTES count];
    int midiNote = [[A_PENT_MIN_NOTES objectAtIndex:(note % count)] intValue] + (12 * (note / count));
    return midiNote;
}

#pragma mark - Dealloc

// on "dealloc" you need to release all your retained objects
- (void) dealloc
{
    //Model
    self.pool = nil;
    //MIDI
    self.midiClock = nil;
    self.sequencePlayer = nil;
    self.audioManager = nil;
    self.audioThread = nil;
    //DisplayLink
    [self.displayLink invalidate];
    self.displayLink = nil;
}

@end