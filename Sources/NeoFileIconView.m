#import "NeoFileIconView.h"

@interface NeoFileIconView ()
{
    UILabel *_extensionLabel;
    UIButton *_buttonView;
}
@end

@implementation NeoFileIconView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        _diameter = 44.0f;

        _extensionLabel = [[UILabel alloc] init];
        _extensionLabel.backgroundColor = [UIColor clearColor];
        _extensionLabel.textColor = [UIColor colorWithRed:0.18f green:0.64f blue:0.90f alpha:1.0f];
        _extensionLabel.font = [UIFont systemFontOfSize:19.0f];
        _extensionLabel.textAlignment = NSTextAlignmentCenter;
        [self addSubview:_extensionLabel];

        _buttonView = [[UIButton alloc] initWithFrame:CGRectMake(0.0f, 0.0f, _diameter, _diameter)];
        _buttonView.backgroundColor = [UIColor clearColor];
        _buttonView.layer.cornerRadius = _diameter / 2.0f;
        _buttonView.clipsToBounds = YES;
        _buttonView.hidden = YES;
        [self addSubview:_buttonView];
    }
    return self;
}

- (void)setDiameter:(CGFloat)diameter
{
    _diameter = diameter;
    _buttonView.layer.cornerRadius = diameter / 2.0f;
    [self setNeedsLayout];
}

- (void)setFileName:(NSString *)fileName
{
    _fileName = fileName;
    NSString *ext = [fileName pathExtension];
    _extensionLabel.text = ext.length > 0 ? ext : [fileName uppercaseString];
    [_extensionLabel sizeToFit];
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    _extensionLabel.center = CGPointMake(self.bounds.size.width / 2.0f, self.bounds.size.height / 2.0f);
    _buttonView.center = _extensionLabel.center;
}

@end
