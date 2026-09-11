/**
 * Tencent is pleased to support the open source community by making QMUI_iOS available.
 * Copyright (C) 2016-2021 THL A29 Limited, a Tencent company. All rights reserved.
 * Licensed under the MIT License (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at
 * http://opensource.org/licenses/MIT
 * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
 */
//
//  UIApplication+QMUI.m
//  QMUIKit
//
//  Created by MoLice on 2021/8/30.
//

#import "UIApplication+QMUI.h"
#import "QMUICore.h"

@implementation UIApplication (QMUI)

QMUISynthesizeBOOLProperty(qmui_addedObserver, setQmui_addedObserver)
QMUISynthesizeBOOLProperty(qmui_didFinishLaunching, setQmui_didFinishLaunching)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        OverrideImplementation(object_getClass(UIApplication.class), @selector(sharedApplication), ^id(__unsafe_unretained Class originClass, SEL originCMD, IMP (^originalIMPProvider)(void)) {
            return ^UIApplication *(UIApplication *selfObject) {
                // call super
                UIApplication * (*originSelectorIMP)(id, SEL);
                originSelectorIMP = (UIApplication * (*)(id, SEL))originalIMPProvider();
                UIApplication * result = originSelectorIMP(selfObject, originCMD);
                
                if (!result.qmui_addedObserver) {
                    [NSNotificationCenter.defaultCenter addObserver:result selector:@selector(qmui_handleDidFinishLaunchingNotification:) name:UIApplicationDidFinishLaunchingNotification object:nil];
                    result.qmui_addedObserver = YES;
                }
                
                return result;
            };
        });
    });
}

- (void)qmui_handleDidFinishLaunchingNotification:(NSNotification *)notification {
    self.qmui_didFinishLaunching = YES;
    [NSNotificationCenter.defaultCenter removeObserver:self name:UIApplicationDidFinishLaunchingNotification object:nil];
}

- (NSArray<__kindof UIWindow *> *)qmui_windows {
    UIWindowScene *activeWindowScene = self.qmui_activeWindowScene;
    if (activeWindowScene.windows.count > 0) {
        return activeWindowScene.windows;
    }

    NSMutableArray<UIWindow *> *windows = NSMutableArray.array;
    for (UIScene *scene in self.connectedScenes) {
        if ([scene isKindOfClass:UIWindowScene.class] && [scene.session.role isEqualToString:UIWindowSceneSessionRoleApplication]) {
            [windows addObjectsFromArray:((UIWindowScene *)scene).windows];
        }
    }
    return windows.copy;
}

- (nullable UIWindowScene *)qmui_activeWindowScene {
    UIWindowScene *bestScene = nil;
    NSInteger bestScore = NSIntegerMin;
    for (UIScene *scene in self.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class] || ![scene.session.role isEqualToString:UIWindowSceneSessionRoleApplication]) {
            continue;
        }

        UIWindowScene *windowScene = (UIWindowScene *)scene;
        NSInteger score = 0;
        switch (windowScene.activationState) {
            case UISceneActivationStateForegroundActive:
                score = 300;
                break;
            case UISceneActivationStateForegroundInactive:
                score = 200;
                break;
            case UISceneActivationStateBackground:
                score = 100;
                break;
            case UISceneActivationStateUnattached:
                break;
        }
        if (windowScene.keyWindow) {
            score += 20;
        } else if ([windowScene.windows indexOfObjectPassingTest:^BOOL(UIWindow *window, NSUInteger idx, BOOL *stop) {
            return !window.isHidden && window.alpha > 0;
        }] != NSNotFound) {
            score += 10;
        }
        if (!bestScene || score > bestScore) {
            bestScene = windowScene;
            bestScore = score;
        }
    }
    return bestScene;
}

- (nullable __kindof UIWindow *)qmui_keyWindow {
    UIWindowScene *windowScene = self.qmui_activeWindowScene;
    UIWindow *keyWindow = windowScene.keyWindow;
    if (!keyWindow) {
        for (UIWindow *window in windowScene.windows) {
            if (window.isKeyWindow && !window.isHidden) {
                keyWindow = window;
                break;
            }
        }
    }
    if (!keyWindow) {
        for (UIWindow *window in windowScene.windows) {
            if (!window.isHidden && window.alpha > 0 && window.windowLevel == UIWindowLevelNormal) {
                keyWindow = window;
                break;
            }
        }
    }
    if (!keyWindow) {
        keyWindow = self.qmui_delegateWindow;
    }
    return keyWindow;
}

- (nullable __kindof UIWindow *)qmui_delegateWindow {
    __block UIWindow *delegateWindow = nil;
    UIWindowScene *activeWindowScene = self.qmui_activeWindowScene;
    if ([activeWindowScene.delegate respondsToSelector:@selector(window)]) {
        delegateWindow = [activeWindowScene.delegate performSelector:@selector(window)];
    }
    if (delegateWindow) {
        return delegateWindow;
    }
    [self.connectedScenes enumerateObjectsUsingBlock:^(UIScene *scene, BOOL *stop) {
        if ([scene isKindOfClass:UIWindowScene.class] && [scene.session.role isEqualToString:UIWindowSceneSessionRoleApplication]) {
            if ([scene.delegate respondsToSelector:@selector(window)]) {
                delegateWindow = [scene.delegate performSelector:@selector(window)];
                *stop = YES;
            }
        }
    }];
    if (!delegateWindow && [self.delegate respondsToSelector:@selector(window)]) {
        delegateWindow = [self.delegate performSelector:@selector(window)];
    }
    return delegateWindow;
}

@end
