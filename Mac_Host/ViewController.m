//
//  ViewController.m
//  ArduinoSerial
//
//  Created by Pat O'Keefe on 4/30/09.
//  Copyright 2009 POP - Pat OKeefe Productions. All rights reserved.
//
//	Portions of this code were derived from Andreas Mayer's work on AMSerialPort. 
//	AMSerialPort was absolutely necessary for the success of this project, and for
//	this, I thank Andreas. This is just a glorified adaptation to present an interface
//	for the ambitious programmer and work well with Arduino serial messages.
//  
//	AMSerialPort is Copyright 2006 Andreas Mayer.
//



#import "ViewController.h"
#import "AMSerialPortList.h"
#import "AMSerialPortAdditions.h"

#define FULL  255
#define FLANK 200
#define HALF  128

#define VERTICAL_MOTOR  0
#define LEFT_MOTOR      1
#define RIGHT_MOTOR     2

@implementation ViewController

//@synthesize serialSelectMenu;
//@synthesize textField;

- (void)awakeFromNib
{
	
	[sendButton setEnabled:NO];
	
	/// set up notifications
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didAddPorts:) name:AMSerialPortListDidAddPortsNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didRemovePorts:) name:AMSerialPortListDidRemovePortsNotification object:nil];
	
	/// initialize port list to arm notifications
	[AMSerialPortList sharedPortList];
	[self listDevices];
	
}

- (IBAction)attemptConnect:(id)sender {
	
	[serialScreenMessage setStringValue:@"Attempting to Connect..."];
	[self initPort];
	
}

// Disconnect from the serial port so that other programs can use it.
// This is useful for Arduino to upload a new program.
- (IBAction)attemptDisConnect:(id)sender {
	
	[serialScreenMessage setStringValue:@"Disconnecting..."];
    if ([port isOpen])
    {
        [port stopReadInBackground];
        [port close];
    
        [connectButton setEnabled:YES];
        [disConnectButton setEnabled:NO];
	}
}
	
# pragma mark Serial Port Stuff
	
	- (void)initPort
	{
		NSString *deviceName = [serialSelectMenu titleOfSelectedItem];
        // Only open the device if it isn't already open
//		if (![deviceName isEqualToString:[port bsdPath]]) {
        if (![port isOpen]) {
			[port close];
			
			[self setPort:[[[AMSerialPort alloc] init:deviceName withName:deviceName type:(NSString*)CFSTR(kIOSerialBSDModemType)] autorelease]];
			[port setDelegate:self];
			
			if ([port open]) {
				
				//Then I suppose we connected!
				NSLog(@"successfully connected");

				[connectButton setEnabled:NO];
                [disConnectButton setEnabled:YES];
				[sendButton setEnabled:YES];
				[serialScreenMessage setStringValue:@"Connection Successful!"];

				//TODO: Set appropriate baud rate here. 
				
				//The standard speeds defined in termios.h are listed near
				//the top of AMSerialPort.h. Those can be preceeded with a 'B' as below. However, I've had success
				//with non standard rates (such as the one for the MIDI protocol). Just omit the 'B' for those.
			
				[port setSpeed:B38400]; 
				

				// listen for data in a separate thread
				[port readDataInBackground];
				
				
			} else { // an error occured while creating port
				
				NSLog(@"error connecting");
				[serialScreenMessage setStringValue:@"Error Trying to Connect..."];
				[self setPort:nil];
				
			}
		}
	}
	
	
	
	
	- (void)serialPortReadData:(NSDictionary *)dataDictionary
	{
		
		AMSerialPort *sendPort = [dataDictionary objectForKey:@"serialPort"];
		NSData *data = [dataDictionary objectForKey:@"data"];
		
		if ([data length] > 0) {
			
			NSString *receivedText = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
			NSLog(@"Serial Port Data Received: %@",receivedText);
			
			
			//TODO: Do something meaningful with the data...
			
			//Typically, I arrange my serial messages coming from the Arduino in chunks, with the
			//data being separated by a comma or semicolon. If you're doing something similar, a 
			//variant of the following command is invaluable. 
			
			//NSArray *dataArray = [receivedText componentsSeparatedByString:@","];

			
			// continue listening
			[sendPort readDataInBackground];

		} else { 
			// port closed
			NSLog(@"Port was closed on a readData operation...not good!");
		}
		
	}
	
	- (void)listDevices
	{
		// get an port enumerator
		NSEnumerator *enumerator = [AMSerialPortList portEnumerator];
		AMSerialPort *aPort;
		[serialSelectMenu removeAllItems];
		
		while (aPort = [enumerator nextObject]) {
			[serialSelectMenu addItemWithTitle:[aPort bsdPath]];
		}
	}
	
	- (IBAction)send:(id)sender
	{
		
		NSString *sendString = [[textField stringValue] stringByAppendingString:@"\r"];
		
		 if(!port) {
		 [self initPort];
		 }
		 
		 if([port isOpen]) {
		 [port writeString:sendString usingEncoding:NSUTF8StringEncoding error:NULL];
		 }
	}
	
	- (AMSerialPort *)port
	{
		return port;
	}
	
	- (void)setPort:(AMSerialPort *)newPort
	{
		id old = nil;
		
		if (newPort != port) {
			old = port;
			port = [newPort retain];
			[old release];
		}
	}

-(void) sendCommandString:(NSString*)command
{
    NSString *sendString = [command stringByAppendingString:@"\r"];
    
    NSLog(@"Sending command: %@", command);
    
    if([port isOpen]) {
        [port writeString:sendString usingEncoding:NSUTF8StringEncoding error:NULL];
    }
}
	
# pragma mark Notifications
	
	- (void)didAddPorts:(NSNotification *)theNotification
	{
		NSLog(@"A port was added");
		[self listDevices];
	}
	
	- (void)didRemovePorts:(NSNotification *)theNotification
	{
		NSLog(@"A port was removed");
		[self listDevices];
	}


#pragma mark Motor Control

-(void) setLeftMotor: (BOOL)forward thrust:(int)value
{
    leftThrustReadout.intValue = value;
    leftThrustIndicator.intValue = value;
    NSString *command = [NSString stringWithFormat:@"M1 %s#%02x", (forward ? "F" : "R"), value];
    [self sendCommandString:command];
}

-(void) setRightMotor: (BOOL)forward thrust:(int)value
{
    rightThrustReadout.intValue = value;
    rightThrustIndicator.intValue = value;
    NSString *command = [NSString stringWithFormat:@"M2 %s#%02x", (forward ? "F" : "R"), value];
    [self sendCommandString:command];
}

-(void) setVerticalMotor: (BOOL)forward thrust:(int)value
{
    verticalThrustReadout.intValue = value;
    verticalThrustIndicator.intValue = value;
    NSString *command = [NSString stringWithFormat:@"M0 %s#%02x", (forward ? "F" : "R"), value];
    [self sendCommandString:command];
}

#pragma mark Running Condition commands to ROV

-(void) engageRunningCondition
{
    // Normal running modes
    [self sendCommandString:@"R"];
}

-(void) engageEmergencyCondition
{
    // Engineering off
    [self sendCommandString:@"E"];
}

-(void) engageEmergencyStopCondition
{
    [self sendCommandString:@"S"];
}
	
#pragma mark Helm Control UI Actions

-(void) finishTrackVertical
{
    NSLog(@"Thrust Vertical finished");
    [verticalThrusterSlider setIntValue:0];
    [self setVerticalMotor: YES thrust:0];
}
- (IBAction)thrustVerticalSliderSet:(id)sender
{
    NSLog(@"Thrust Vertical set");
    [NSObject cancelPreviousPerformRequestsWithTarget: self
                                             selector: @selector(finishTrackVertical) object: nil ];
    [self performSelector: @selector(finishTrackVertical) withObject: nil
               afterDelay: 0.0];
    int control = [verticalThrusterSlider intValue];
    // motor direction
    BOOL isForward = control >= 0;
    // Get the absolute value of the control for motor speed
    control = control < 0 ? -control : control;
    [self setVerticalMotor: isForward thrust:control];
}



-(void) finishTrackLR
{
    NSLog(@"Thrust LR finished");
    [self setLeftMotor:YES thrust:0];
    [self setRightMotor:YES thrust:0];
}

- (IBAction)thrustForward:(id)sender
{
    NSLog(@"forward");
    [NSObject cancelPreviousPerformRequestsWithTarget: self
                                             selector: @selector(finishTrackLR) object: nil ];
    [self performSelector: @selector(finishTrackLR) withObject: nil
               afterDelay: 0.0];
    [self setLeftMotor:YES thrust:FLANK];
    [self setRightMotor:YES thrust:FLANK];
}

- (IBAction)thrustForwardRight:(id)sender
{
    NSLog(@"forward right");
    [NSObject cancelPreviousPerformRequestsWithTarget: self
                                             selector: @selector(finishTrackLR) object: nil ];
    [self performSelector: @selector(finishTrackLR) withObject: nil
               afterDelay: 0.0];
    [self setLeftMotor:YES thrust:FLANK];
    [self setRightMotor:YES thrust:0];
}

- (IBAction)thrustForwardLeft:(id)sender
{
    NSLog(@"forward left");
    [NSObject cancelPreviousPerformRequestsWithTarget: self
                                             selector: @selector(finishTrackLR) object: nil ];
    [self performSelector: @selector(finishTrackLR) withObject: nil
               afterDelay: 0.0];
    [self setLeftMotor:YES thrust:0];
    [self setRightMotor:YES thrust:FLANK];
}

- (IBAction)thrustLeft:(id)sender
{
    NSLog(@"left");
    [NSObject cancelPreviousPerformRequestsWithTarget: self
                                             selector: @selector(finishTrackLR) object: nil ];
    [self performSelector: @selector(finishTrackLR) withObject: nil
               afterDelay: 0.0];
    [self setLeftMotor:NO thrust:HALF];
    [self setRightMotor:YES thrust:HALF];
}

- (IBAction)thrustRight:(id)sender
{
    NSLog(@"right");
    [NSObject cancelPreviousPerformRequestsWithTarget: self
                                             selector: @selector(finishTrackLR) object: nil ];
    [self performSelector: @selector(finishTrackLR) withObject: nil
               afterDelay: 0.0];
    [self setLeftMotor:YES thrust:HALF];
    [self setRightMotor:NO thrust:HALF];
}

- (IBAction)thrustReverse:(id)sender
{
    NSLog(@"reverse");
    [NSObject cancelPreviousPerformRequestsWithTarget: self
                                             selector: @selector(finishTrackLR) object: nil ];
    [self performSelector: @selector(finishTrackLR) withObject: nil
               afterDelay: 0.0];
    [self setLeftMotor:NO thrust:FLANK];
    [self setRightMotor:NO thrust:FLANK];
}

- (IBAction)thrustReverseRight:(id)sender
{
    NSLog(@"reverse right");
    [NSObject cancelPreviousPerformRequestsWithTarget: self
                                             selector: @selector(finishTrackLR) object: nil ];
    [self performSelector: @selector(finishTrackLR) withObject: nil
               afterDelay: 0.0];
    [self setLeftMotor:NO thrust:FLANK];
    [self setRightMotor:YES thrust:0];
}

- (IBAction)thrustReverseLeft:(id)sender
{
    NSLog(@"reverse left");
    [NSObject cancelPreviousPerformRequestsWithTarget: self
                                             selector: @selector(finishTrackLR) object: nil ];
    [self performSelector: @selector(finishTrackLR) withObject: nil
               afterDelay: 0.0];
    [self setLeftMotor:YES thrust:0];
    [self setRightMotor:NO thrust:FLANK];
}




// Full STOP. Turn off all motors. Ignore Motor commands until running mode received. Engage rescue beacon.
- (IBAction)fullStopCondition:(id)sender
{
    NSLog(@"Emergency STOP condition pressed");
    [self engageEmergencyStopCondition];
}

// Normal running conditions.
- (IBAction)normalRunningCondition:(id)sender
{
    NSLog(@"Normal Running condition pressed");
    [self engageRunningCondition];
}

// Emergency Surface. Run vertical motor for 5 seconds and turn on resuce beacon.
- (IBAction)emergencySurfaceCondition:(id)sender
{
    NSLog(@"Emergency Surface condition pressed");
    [self engageEmergencyCondition];
}


@end
