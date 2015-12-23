//
//  ViewController.m
//  SceneKitHitTest
//
//  Created by Akira Iwaya on 2015/12/17.
//  Copyright © 2015年 akira108. All rights reserved.
//

#import "ViewController.h"
@import SceneKit;

@interface ViewController ()
@property(nonatomic, weak)IBOutlet SCNView *scnView;
@property(nonatomic, strong)SCNNode *cameraPivotNode;
@property(nonatomic, strong)NSArray <SCNNode *> *selectedNodes;
@property(nonatomic, assign)CGPoint dragDelta;
@property(nonatomic, assign)CGPoint dragInitialLocation;
@property(nonatomic, assign)CGPoint previousLocation;
@property(nonatomic, assign)SCNVector3 previousUnprojectedPoint;
@property(nonatomic, assign)SCNVector3 hitResultWorldCoordinate;
@property(nonatomic, assign)SCNVector3 hitResultDocumentNodeCoordinate;
@property(nonatomic, assign)SCNVector3 hitResultDocumentNodeCoordinateProjectedPoint;
@property(nonatomic, strong)SCNNode *documentNode;
@property(nonatomic, strong)SCNScene *scene;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.scene = [SCNScene scene];
    self.scnView.scene = self.scene;
    self.scnView.autoenablesDefaultLighting = YES;
//    self.scnView.allowsCameraControl = YES;
    self.scnView.backgroundColor = [UIColor lightGrayColor];
    
    UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    [self.view addGestureRecognizer:tapRecognizer];
    
    UIPanGestureRecognizer *panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [self.view addGestureRecognizer:panRecognizer];
    
//     A square box with sharp corners
    // -------------------------------
    
    SCNPlane *documentPlane = [SCNPlane planeWithWidth:30 height:60];
    documentPlane.firstMaterial.diffuse.contents = [UIColor greenColor];
    self.documentNode = [SCNNode nodeWithGeometry:documentPlane];
    [self.scene.rootNode addChildNode:self.documentNode];
    
    SCNBox *box = [SCNBox boxWithWidth:10 height:10 length:10 chamferRadius:0.0];
    box.firstMaterial.diffuse.contents = [UIColor blueColor];
    SCNNode *boxNode = [SCNNode nodeWithGeometry:box];
    [self.scene.rootNode addChildNode:boxNode];
    
    SCNNode *cameraNode = [SCNNode node];
    cameraNode.camera   = [SCNCamera camera];
    cameraNode.position = SCNVector3Make(10, 10, 50);
    cameraNode.camera.zNear = 1;
    cameraNode.camera.zFar = 1000;
    SCNLookAtConstraint *constraint = [SCNLookAtConstraint lookAtConstraintWithTarget:self.documentNode];
    constraint.gimbalLockEnabled = YES;
    cameraNode.constraints = @[constraint];
    [self.scene.rootNode addChildNode:cameraNode];
    self.scnView.pointOfView = cameraNode;
    
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
//    
//    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"rotation"];
//    animation.fromValue = [NSValue valueWithSCNVector4:SCNVector4Make(0.0, 1.0, 0.0, 0.0)];
//    animation.toValue = [NSValue valueWithSCNVector4:SCNVector4Make(0.0, 1.0, 0.0, M_PI * 2 - 0.01)];
//    animation.duration = 100.0;
//    animation.autoreverses = YES;
//    animation.repeatCount = INFINITY;
//    [self.cameraPivotNode addAnimation:animation forKey:@"rotation"];
    
    
//    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:1.0 / 30.0 target:self selector:@selector(tick:) userInfo:nil repeats:YES];
}

- (void)tick:(NSTimer *)timer {
    SCNVector4 r = self.cameraPivotNode.rotation;
    self.cameraPivotNode.rotation = SCNVector4Make(0.0, 1.0, 0.0, r.w += 0.01);
}

- (void)handleTap:(UITapGestureRecognizer *)tap {
    CGPoint location = [tap locationInView:self.scnView];
    
    NSArray <SCNHitTestResult *> *results = [self.scnView hitTest:location options:nil];
    
    NSLog(@"results = %@", results);
    
    [self.scnView.scene.rootNode enumerateChildNodesUsingBlock:^(SCNNode * _Nonnull node, BOOL * _Nonnull stop) {
        node.geometry.firstMaterial.emission.contents = nil;
    }];
    
    if ([results count] > 0) {
        SCNHitTestResult *result = results.firstObject;
        self.selectedNodes = @[result.node];
        self.hitResultWorldCoordinate = result.worldCoordinates;
        [self printSCNVector3:self.hitResultWorldCoordinate name:@"hitResultWorldCoordinate"];
        self.hitResultDocumentNodeCoordinate = [self.documentNode convertPosition:self.hitResultDocumentNodeCoordinate fromNode:self.scene.rootNode];
        results.firstObject.node.geometry.firstMaterial.emission.contents = [UIColor redColor];
    }
}

- (void)printSCNVector3:(SCNVector3)vector name: (NSString *)name {
    NSLog(@"%@ = (%f, %f, %f)", name, vector.x, vector.y, vector.z);
}

- (void)handlePan:(UIPanGestureRecognizer *)panRecognizer {
    if ([self.selectedNodes count] == 0) {
        return;
    }
    
    CGPoint location = [panRecognizer locationInView:self.view];
    switch (panRecognizer.state) {
        case UIGestureRecognizerStateBegan:
            self.dragInitialLocation = location;
            self.previousLocation = self.dragInitialLocation;
            self.hitResultDocumentNodeCoordinateProjectedPoint = [self.scnView projectPoint:self.hitResultWorldCoordinate];
            
            SCNVector3 unprojectedPoint = [self.scnView unprojectPoint:SCNVector3Make(location.x, location.y, self.hitResultDocumentNodeCoordinateProjectedPoint.z)];
            self.previousUnprojectedPoint = [self.documentNode convertPosition:unprojectedPoint fromNode:nil];
            [self printSCNVector3:unprojectedPoint name:@"initial location in woorld coords"];
            [self printSCNVector3:self.previousUnprojectedPoint name:@"initial location in documentNode"];
            break;
        case UIGestureRecognizerStateChanged: {
            SCNVector3 unprojectedPoint = [self.documentNode convertPosition:[self.scnView unprojectPoint:SCNVector3Make(location.x, location.y, self.hitResultDocumentNodeCoordinateProjectedPoint.z)] fromNode:nil];
            [self printSCNVector3:unprojectedPoint name:@"unproj"];
            
            SCNVector3 delta = SCNVector3Make(unprojectedPoint.x - self.previousUnprojectedPoint.x, unprojectedPoint.y - self.previousUnprojectedPoint.y, unprojectedPoint.z - self.previousUnprojectedPoint.z);
            
            [self printSCNVector3:delta name:@"delta"];
            SCNNode *selected = self.selectedNodes.firstObject;
            selected.position = SCNVector3Make(selected.position.x + delta.x, selected.position.y + delta.y, selected.position.z + delta.z);
            self.previousUnprojectedPoint = unprojectedPoint;
            self.previousLocation = location;
            break;
        }
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
            break;
        default:
            break;
    }
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
