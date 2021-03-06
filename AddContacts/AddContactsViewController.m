//
//  AddContactsViewController.m
//  AddContacts
//
//  Created by Jason Bandy on 2/10/14.
//  Copyright (c) 2014 Jason Bandy. All rights reserved.
//

#import "AddContactsViewController.h"
#import <AddressBook/AddressBook.h>
#import <AddressBookUI/AddressBookUI.h>

typedef enum {
    FailedAdd,
    SomeSuccessAdd,
    SuccessAdd,
    FailedRemove,
    SomeSuccessRemove,
    SuccessRemove
}StatusType;

#define DELETE_ALL_CONFIRM_ALERT 101

@interface AddContactsViewController () {
    StatusType workStatus;
}
@property (nonatomic, assign) ABAddressBookRef addressBook;

@property (strong, nonatomic) IBOutlet UIButton *goButton;
@property (strong, nonatomic) IBOutlet UIButton *removeAddedContactsButton;
@property (strong, nonatomic) IBOutlet UITextField *createQuantityTextField;
@property (strong, nonatomic) IBOutlet UITextField *deleteQuantityTextField;
@property (strong, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;
@property (strong, nonatomic) IBOutlet UILabel *statusLabel;
@property (strong, nonatomic) IBOutlet UISwitch *withImagesSwitch;
@property (strong, nonatomic) IBOutlet UILabel *progressLabel;
@property BOOL accessGranted;

// Properties for hiding keyboard by touching off keyboard
@property (strong, nonatomic) UIGestureRecognizer *tap;
@property (strong, nonatomic) UITextField *textFieldWithFocus;

@end

@implementation AddContactsViewController

#pragma mark - View Life Cycle Methods
-(void)viewDidLoad {
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    self.accessGranted = NO;
    [self requestAddressBookAccess];
    
    //disabling this button while the operation doesn't work
    self.removeAddedContactsButton.enabled = NO;
    [self.removeAddedContactsButton setTitleColor:[UIColor grayColor] forState:UIControlStateNormal];
    
    self.tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
    self.tap.cancelsTouchesInView = NO;
}

-(void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)requestAddressBookAccess {
    AddContactsViewController * __weak weakSelf = self;
    
    ABAddressBookRequestAccessWithCompletion(self.addressBook, ^(bool granted, CFErrorRef error)
                                             {
                                                 if (granted)
                                                 {
                                                     dispatch_async(dispatch_get_main_queue(), ^{
                                                         [weakSelf accessGrantedForAddressBook];
                                                         
                                                     });
                                                 }
                                             });
}

#pragma mark - Private Methods
-(void)accessGrantedForAddressBook {
    self.accessGranted = YES;
}

-(void)reportStatus:(StatusType)status {
    switch (status) {
        case FailedAdd:
            self.statusLabel.text = @"Failed to add contacts to ABook.";
            self.statusLabel.hidden = NO;
            break;
        case SomeSuccessAdd:
            self.statusLabel.text = @"Contacts added with some errors.";
            self.statusLabel.hidden = NO;
            break;
        case SuccessAdd:
            self.statusLabel.text = @"Contacts added with no errors!";
            self.statusLabel.hidden = NO;
            break;
        case FailedRemove:
            self.statusLabel.text = @"Failed to remove contacts from ABook.";
            self.statusLabel.hidden = NO;
            break;
        case SomeSuccessRemove:
            self.statusLabel.text = @"Contacts removed with some errors.";
            self.statusLabel.hidden = NO;
            break;
        case SuccessRemove:
            self.statusLabel.text = @"Contacts removed with no errors!";
            self.statusLabel.hidden = NO;
            break;
            
        default:
            break;
    }
}

-(void)removeContacts: (int)numberToRemove {
    workStatus = SuccessRemove;
    CFErrorRef bookError = NULL;
    ABAddressBookRef book = ABAddressBookCreateWithOptions(nil, &bookError);
    
    
    
    if (bookError == NULL) {
        
        ABRecordRef source = ABAddressBookCopyDefaultSource(book);
        CFArrayRef allPeople = ABAddressBookCopyArrayOfAllPeopleInSourceWithSortOrdering(book, source, kABPersonSortByFirstName);
        

        for (int r = 0; r < numberToRemove && CFArrayGetCount(allPeople) != 0; r++) {
            [self updateProgressLabelText:r total:(int)numberToRemove];
            
            CFErrorRef removeError = NULL;
            ABRecordRef personToRemove = CFArrayGetValueAtIndex(allPeople,r);
            ABAddressBookRemoveRecord(book, personToRemove, &removeError);
            if (removeError != NULL) {
                NSLog(@"Unable to remove contact %@", personToRemove);
                workStatus = SomeSuccessRemove;
            }
        }
        ABAddressBookSave(book, &bookError);
        
    } else {
        NSLog(@"Unable to remove contacts");
        workStatus = FailedRemove;
    }
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        [self.activityIndicator stopAnimating];
        [self reportStatus:workStatus];
    });
}

-(void)removeAddedContacts {
    workStatus = SuccessRemove;
    CFErrorRef bookError = NULL;
    ABAddressBookRef book = ABAddressBookCreateWithOptions(nil, &bookError);
    
    
    if (bookError == NULL) {
        
        NSString *nameInContact = @"TestContact";
        CFArrayRef allPeople = ABAddressBookCopyPeopleWithName(book, (__bridge CFStringRef)(nameInContact));

        CFIndex nPeople = CFArrayGetCount(allPeople);
        
        for (int r = 0; r < nPeople; r++) {
            [self updateProgressLabelText:r total:(int)nPeople];
            
            CFErrorRef removeError = NULL;
            ABRecordRef personToRemove = CFArrayGetValueAtIndex(allPeople,r);
            ABAddressBookRemoveRecord(book, personToRemove, &removeError);
            if (removeError != NULL) {
                NSLog(@"Unable to remove contact %@", personToRemove);
                workStatus = SomeSuccessRemove;
            }
        }
        ABAddressBookSave(book, &bookError);
        
    } else {
        NSLog(@"Unable to remove contacts");
        workStatus = FailedRemove;
    }
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        [self.activityIndicator stopAnimating];
        [self reportStatus:workStatus];
    });
}

-(void)createContacts {
    workStatus = SuccessAdd;
    CFErrorRef bookError = NULL;
    ABAddressBookRef book = ABAddressBookCreateWithOptions(nil, &bookError);
    
    if (bookError == NULL) {
        int numContacts = [self.createQuantityTextField.text intValue];
        for (int i = 0; i< numContacts; i++) {
            
            [self updateProgressLabelText:i total:numContacts];
            
            CFErrorRef contentError = NULL;
            
            // create person info strings
            NSString *fName = @"TestContact";
            NSString *lName = [NSString stringWithFormat:@"%d_last",i];
            NSString *phoneNumber = [NSString stringWithFormat:@"%lld", (long long)arc4random() %99999999999 + 10000000000]; // 999.999.9999
            NSString *streetAddress = [NSString stringWithFormat:@"%d street", arc4random()%9999 + 1000];
            NSString *city = [NSString stringWithFormat:@"Nashville"];
            NSString *state = @"TN";
            NSString *zipCode = @"37216";
            NSString *country = @"USA";
            NSString *email = @"contact@domain.com";
            UIImage *contactImage = [UIImage imageNamed:@"yoda.png"];
            
            // create person and assign property for contact
            ABRecordRef person = ABPersonCreate();
            ABRecordSetValue(person, kABPersonFirstNameProperty, (__bridge CFStringRef)fName, NULL);
            ABRecordSetValue(person, kABPersonLastNameProperty, (__bridge CFStringRef)lName, NULL);
            
            ABMutableMultiValueRef multiPhone = ABMultiValueCreateMutable(kABMultiStringPropertyType);
            ABMultiValueAddValueAndLabel(multiPhone, (__bridge CFTypeRef)(phoneNumber), kABPersonPhoneIPhoneLabel, NULL);
            ABRecordSetValue(person, kABPersonPhoneProperty, multiPhone,NULL);
            CFRelease(multiPhone);
            
            ABMutableMultiValueRef multiAddress = ABMultiValueCreateMutable(kABMultiDictionaryPropertyType);
            NSMutableDictionary *addressDictionary = [[NSMutableDictionary alloc] init];
            [addressDictionary setObject:streetAddress forKey:(NSString *) kABPersonAddressStreetKey];
            [addressDictionary setObject:city forKey:(NSString *) kABPersonAddressCityKey];
            [addressDictionary setObject:state forKey:(NSString *) kABPersonAddressStateKey];
            [addressDictionary setObject:zipCode forKey:(NSString *) kABPersonAddressZIPKey];
            [addressDictionary setObject:country forKey:(NSString *) kABPersonAddressCountryKey];
            ABMultiValueAddValueAndLabel(multiAddress, (__bridge CFTypeRef)(addressDictionary), kABHomeLabel, NULL);
            ABRecordSetValue(person, kABPersonAddressProperty, multiAddress,&contentError);
            CFRelease(multiAddress);
            
            
            ABMutableMultiValueRef multiEmail = ABMultiValueCreateMutable(kABMultiStringPropertyType);
            ABMultiValueAddValueAndLabel(multiEmail, (__bridge CFTypeRef)(email), kABHomeLabel, NULL);
            ABRecordSetValue(person, kABPersonEmailProperty, multiEmail, &contentError);
            CFRelease(multiEmail);
            
            if (self.withImagesSwitch.on) {
                NSData *data = UIImagePNGRepresentation(contactImage);
                ABPersonSetImageData(person, (__bridge CFDataRef)(data), &contentError);
            }
            
            CFErrorRef addError = NULL;
            ABAddressBookAddRecord(book, person, &addError);
            ABAddressBookSave(book, &addError);
            
            if (contentError != NULL) {
                NSLog(@"Unable to add content for contact %d with error: %@",i, contentError);
                workStatus = SomeSuccessAdd;
            }
            
            if (addError != NULL) {
                NSLog(@"Unable to add contact %d to ABbook with error: %@",i, addError);
                workStatus = SomeSuccessAdd;
            }
        }
    } else {
        NSLog(@"Unable to access Address Book!");
        workStatus = FailedAdd;
    }
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        [self.activityIndicator stopAnimating];
        [self reportStatus:workStatus];
    });
}

-(void)dismissKeyboard {
    [self.textFieldWithFocus resignFirstResponder];
}

#pragma mark - UITextField Delegate Methods
-(void)textFieldDidBeginEditing:(UITextField *)textField {
    self.statusLabel.hidden = YES;
    textField.text = nil;
    
    self.textFieldWithFocus = textField;
    [self.view addGestureRecognizer:self.tap];
}

-(void)textFieldDidEndEditing:(UITextField *)textField {
    if (textField == self.textFieldWithFocus) {
        self.textFieldWithFocus = nil;
        [self.view removeGestureRecognizer:self.tap];
    }
}

#pragma mark - IBAction Methods
-(IBAction)userTouchedGoButtonWithSender:(UIButton *)sender {
    self.statusLabel.hidden = YES;
    [self.createQuantityTextField resignFirstResponder];
    [self.activityIndicator startAnimating];
    if (self.accessGranted) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self createContacts];
        });
        
        }
}
- (IBAction)userTouchedRemoveAllContactsWithSender:(UIButton *)sender {
    UIAlertView *removeAllConfirmAlert = [[UIAlertView alloc]initWithTitle:@"Are You Sure?"
                                                                   message:@"Press ok to delete all contacts in your address book."
                                                                  delegate:self
                                                         cancelButtonTitle:@"Cancel"
                                                         otherButtonTitles:@"OK", nil];
    removeAllConfirmAlert.tag = DELETE_ALL_CONFIRM_ALERT;
    [removeAllConfirmAlert show];
}

-(IBAction)userTouchedRemoveAddedContactsWithSender:(UIButton *)sender {
    self.statusLabel.hidden = YES;
    [self.createQuantityTextField resignFirstResponder];
    [self.activityIndicator startAnimating];
    if (self.accessGranted) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self removeAddedContacts];
        });
    }
}

-(IBAction)userTouchedRemoveXContactsWithSender:(id)sender {
    self.statusLabel.hidden = YES;
    [self.deleteQuantityTextField resignFirstResponder];
    [self.activityIndicator startAnimating];
    if (self.accessGranted) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self removeContacts:self.deleteQuantityTextField.text.intValue];
        });
    }
}

#pragma mark - Helpers
-(void)updateProgressLabelText: (int)currentlyOn total:(int)total {
    dispatch_async(dispatch_get_main_queue(), ^(void) {
     self.progressLabel.text = [NSString stringWithFormat:@"%i/%i", currentlyOn + 1, total];
    });
}

#pragma mark - UIAlertView Delegate Methods
-(void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (alertView.tag != DELETE_ALL_CONFIRM_ALERT) {
        return;
    }
    switch (buttonIndex) {
        case 1:// OK clicked
            self.statusLabel.hidden = YES;
            [self.createQuantityTextField resignFirstResponder];
            [self.activityIndicator startAnimating];
            if (self.accessGranted) {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    CFErrorRef bookError = NULL;
                    ABAddressBookRef book = ABAddressBookCreateWithOptions(nil, &bookError);
                    CFIndex nPeople = ABAddressBookGetPersonCount(book);
                    [self removeContacts:(int)nPeople ];
                });
            }
            break;
            
        default: // Cancel Clicked
            // do nothing
            break;
    }
}

@end
