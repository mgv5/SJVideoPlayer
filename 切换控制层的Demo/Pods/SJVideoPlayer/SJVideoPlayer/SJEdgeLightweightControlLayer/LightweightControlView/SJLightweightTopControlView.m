//
//  SJLightweightTopControlView.m
//  SJVideoPlayerProject
//
//  Created by BlueDancer on 2018/3/21.
//  Copyright © 2018年 SanJiang. All rights reserved.
//

#import "SJLightweightTopControlView.h"
#import <SJUIFactory/SJUIFactory.h>
#import <Masonry/Masonry.h>
#import "UIView+SJVideoPlayerSetting.h"
#import <SJAttributesFactory/SJAttributeWorker.h>
#import "SJLightweightTopItem.h"
#import <objc/message.h>

NS_ASSUME_NONNULL_BEGIN


@interface SJLightweightTopTmp : NSObject

- (instancetype)initWithItem:(SJLightweightTopItem *)item;

@property (nonatomic, strong, readonly) SJLightweightTopItem *item;

@property (nonatomic, copy, nullable) void(^updatedExeBlock)(SJLightweightTopTmp *tmp);

@end

@implementation SJLightweightTopTmp

- (instancetype)initWithItem:(SJLightweightTopItem *)item {
    self = [super init];
    if ( !self ) return nil;
    _item = item;
    [item addObserver:self forKeyPath:kLightweightTopItemImageNameKeyPath options:NSKeyValueObservingOptionNew context:nil];
    return self;
}

- (void)observeValueForKeyPath:(nullable NSString *)keyPath ofObject:(nullable id)object change:(nullable NSDictionary<NSKeyValueChangeKey, id> *)change context:(nullable void *)context {
    if ( [keyPath isEqualToString:kLightweightTopItemImageNameKeyPath] ) {
        if ( _updatedExeBlock ) _updatedExeBlock(self);
    }
}

- (void)dealloc {
    [_item removeObserver:self forKeyPath:kLightweightTopItemImageNameKeyPath];
}
@end

@interface SJLightweightTopControlView () {
    SJLightweightTopControlModel *_model;
}

@property (nonatomic, strong, readonly) UILabel *titleLabel;
@property (nonatomic, strong, readonly) UIView *itemsContainerView;
@property (nonatomic, strong, readwrite, nullable) NSArray<SJLightweightTopTmp *> *observerItems;

@end

@implementation SJLightweightTopControlView
@synthesize itemsContainerView = _itemsContainerView;
@synthesize backBtn = _backBtn;
@synthesize titleLabel = _titleLabel;

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if ( !self ) return nil;
    [self _topSetupViews];
    [self _topSettingHelper];
    return self;
}

- (CGSize)intrinsicContentSize {
    if ( _isFullscreen ) {
        return CGSizeMake(SJScreen_Max(), 72);
    }
    else {
        return CGSizeMake(SJScreen_Min(), 55);
    }
}

- (void)setIsFullscreen:(BOOL)isFullscreen {
    if ( isFullscreen == _isFullscreen ) return;
    _isFullscreen = isFullscreen;
    [self invalidateIntrinsicContentSize];
}

- (void)setTopItems:(NSArray<SJLightweightTopItem *> * __nullable)topItems {
    if ( topItems == _topItems ) return;
    _observerItems = nil;
    
    _topItems = topItems;
    
    [_itemsContainerView.subviews enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(__kindof UIView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [obj removeFromSuperview];
    }];
    
    NSMutableArray<SJLightweightTopTmp *> *observerItemsM = [NSMutableArray array];
    [topItems enumerateObjectsUsingBlock:^(SJLightweightTopItem * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        UIButton *btn = [SJUIButtonFactory buttonWithImageName:obj.imageName target:self sel:@selector(clickedTopItem:) tag:idx];
        [self->_itemsContainerView addSubview:btn];
        if ( idx == 0 ) {
            [btn mas_makeConstraints:^(MASConstraintMaker *make) {
                make.leading.bottom.offset(0);
                make.size.offset(44);
            }];
        }
        else {
            UIButton *beforeBtn = self->_itemsContainerView.subviews[(int)idx - 1];
            [btn mas_makeConstraints:^(MASConstraintMaker *make) {
                make.size.bottom.equalTo(beforeBtn);
                make.leading.equalTo(beforeBtn.mas_trailing);
                if ( idx == (int)topItems.count - 1 ) {
                    make.trailing.offset(0);
                }
            }];
        }
        // update image
        SJLightweightTopTmp *observer = [[SJLightweightTopTmp alloc] initWithItem:obj];
        observer.updatedExeBlock = ^(SJLightweightTopTmp * _Nonnull tmp) {
            [btn setImage:[UIImage imageNamed:tmp.item.imageName] forState:UIControlStateNormal];
        };
        [observerItemsM addObject:observer];
    }];
    
    _observerItems = observerItemsM;
}

- (void)clickedTopItem:(UIButton *)btn {
    if ( [self.delegate respondsToSelector:@selector(topControlView:clickedItem:)] ) {
        [self.delegate topControlView:self clickedItem:_topItems[btn.tag]];
    }
}

- (void)needUpdateLayout {
    
    self.itemsContainerView.hidden = (!_isFullscreen && self.model.isPlayOnScrollView);
    
    if ( self.isFullscreen ) {
        self.titleLabel.hidden = NO;
    }
    else {
        self.titleLabel.hidden = !self.model.alwaysShowTitle;
    }
    
    if ( !self.titleLabel.hidden ) {
        NSAttributedString *attrStr = nil;
        if ( 0 != self.model.title.length ) {
            attrStr = sj_makeAttributesString(^(SJAttributeWorker * _Nonnull make) {
                make.font(self.titleLabel.font).textColor(self.titleLabel.textColor);
                make.insert(self.model.title, 0);
                make.shadow(CGSizeMake(0.5, 0.5), 1, [UIColor blackColor]);
            });
        }
        _titleLabel.attributedText = attrStr;
    }
    
    if ( _isFullscreen || !self.model.isPlayOnScrollView ) {
        _backBtn.hidden = NO;
        [_titleLabel mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.leading.equalTo(self->_backBtn.mas_trailing);
            make.centerY.equalTo(self->_backBtn);
            make.trailing.equalTo(self->_itemsContainerView.mas_leading);
        }];
    }
    else {
        _backBtn.hidden = YES;
        [_titleLabel mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.leading.offset(16);
            make.centerY.equalTo(self->_backBtn);
            make.trailing.offset(-16);
        }];
    }
}

- (void)clickedBtn:(UIButton *)btn {
    if ( ![_delegate respondsToSelector:@selector(clickedBackBtnOnTopControlView:)] ) return;
    [_delegate clickedBackBtnOnTopControlView:self];
}

- (void)_topSetupViews {
    
    [self addSubview:self.backBtn];
    [self addSubview:self.titleLabel];
    [self addSubview:self.itemsContainerView];
    
    [_backBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.size.offset(49);
        make.leading.bottom.offset(0);
    }];
    
    [_titleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.leading.equalTo(self->_backBtn.mas_trailing);
        make.centerY.equalTo(self->_backBtn);
        make.trailing.equalTo(self->_itemsContainerView.mas_leading);
    }];
    
    [_itemsContainerView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.trailing.bottom.offset(0);
        make.width.mas_greaterThanOrEqualTo(8);
    }];
    
    [SJUIFactory boundaryProtectedWithView:_backBtn];
}

- (UIButton *)backBtn {
    if ( _backBtn ) return _backBtn;
    _backBtn = [SJUIButtonFactory buttonWithImageName:nil target:self sel:@selector(clickedBtn:) tag:0];
    return _backBtn;
}

- (UILabel *)titleLabel {
    if ( _titleLabel ) return _titleLabel;
    _titleLabel = [UILabel new];
    return _titleLabel;
}

#pragma mark -
- (void)_topSettingHelper {
    __weak typeof(self) _self = self;
    self.settingRecroder = [[SJVideoPlayerControlSettingRecorder alloc] initWithSettings:^(SJEdgeControlLayerSettings * _Nonnull setting) {
        __strong typeof(_self) self = _self;
        if ( !self ) return;
        [self.backBtn setImage:setting.backBtnImage forState:UIControlStateNormal];
        self.titleLabel.font = setting.titleFont;
        self.titleLabel.textColor = setting.titleColor;
        if ( 0 != self.model.title.length ) self.titleLabel.text = self.model.title;
    }];
}
- (SJLightweightTopControlModel *)model {
    if ( _model ) return _model;
    _model = [SJLightweightTopControlModel new];
    return _model;
}
- (UIView *)itemsContainerView {
    if ( _itemsContainerView ) return _itemsContainerView;
    _itemsContainerView = [UIView new];
    return _itemsContainerView;
}
@end


@implementation SJLightweightTopControlModel
@end
NS_ASSUME_NONNULL_END
