//
//  ViewController.h
//  ArduinoSerial
//
//  Created by Pat O'Keefe on 4/30/09.
//  Copyright 2009 POP - Pat OKeefe Productions. All rights reserved.
//
//	Portions of this code were derived from Andreas Mayer's work on AMSerialPort. 
//	AMSerialPort was absolutely necessary for the success of this project, and for
//	this, I thanks Andreas. This is just a glorified adaptation to present an interface
//	for the ambitious programmer and work well with Arduino serial messages.
//  
//	AMSerialPort is Copyright 2006 Andreas Mayer.
//


#import <Cocoa/Cocoa.h>
#import "AMSerialPort.h"

enum RunningState {
    ConditionFullStop = 1,
    ConditionRunning,
    ConditionEmergencySurface
};

@interface ViewController : NSObject {

	AMSerialPort *port;
    
    enum RunningState state;
	
    // Serial Port UI Elements
	IBOutlet NSPopUpButton	*serialSelectMenu;
	IBOutlet NSTextField	*textField;
	IBOutlet NSButton		*connectButton, *sendButton, *disConnectButton;
	IBOutlet NSTextField	*serialScreenMessage;
    
    // ROV Navigation UI Elements
    IBOutlet NSSlider         *verticalThrusterSlider;
    IBOutlet NSTextField      *temperatureReadout;
    IBOutlet NSLevelIndicator *leftThrustIndicator, *rightThrustIndicator, *verticalThrustIndicator;
    IBOutlet NSTextField      *leftThrustReadout, *rightThrustReadout, *verticalThrustReadout;
    
    IBOutlet NSColorWell      *leakIndicator;
}

// Interface Methods
- (IBAction)attemptConnect:(id)sender;
- (IBAction)attemptDisConnect:(id)sender;
- (IBAction)send:(id)sender;

// Navigation Joy Stick Emulation
- (IBAction)thrustForward:(id)sender;
- (IBAction)thrustForwardRight:(id)sender;
- (IBAction)thrustForwardLeft:(id)sender;
- (IBAction)thrustLeft:(id)sender;
- (IBAction)thrustRight:(id)sender;
- (IBAction)thrustReverse:(id)sender;
- (IBAction)thrustReverseRight:(id)sender;
- (IBAction)thrustReverseLeft:(id)sender;

// Vertical Thrust Slider Action
- (IBAction)thrustVerticalSliderSet:(id)sender;

// Serial Port Methods
- (AMSerialPort *)port;
- (void)setPort:(AMSerialPort *)newPort;
- (void)listDevices;
- (void)initPort;


//@property (nonatomic, retain) IBOutlet NSPopUpButton *serialSelectMenu;
//@property (nonatomic, retain) IBOutlet NSTextField	 *textField;

@end