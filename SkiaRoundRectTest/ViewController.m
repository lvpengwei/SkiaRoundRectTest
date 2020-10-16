//
//  ViewController.m
//  SkiaRoundRectTest
//
//  Created by lvpengwei on 2020/10/16.
//

#import "ViewController.h"
#import "SkiaLayer.h"

@interface ViewController ()

@property (nonatomic, weak) SkiaLayer *skiaLayer;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    SkiaLayer *skiaLayer = [[SkiaLayer alloc] init];
    skiaLayer.frame = CGRectMake(100, 400, 200, 200);
    [self.view.layer addSublayer:skiaLayer];
    self.skiaLayer = skiaLayer;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.skiaLayer draw];
}

- (IBAction)buttonAction:(id)sender {
    [self.skiaLayer draw];
}

@end
