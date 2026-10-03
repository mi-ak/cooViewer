#import <Cocoa/Cocoa.h>

// Existing preferences may still contain unkeyed archives from older releases.
static inline id COReadArchivedSetting(NSUserDefaults *defaults, NSString *key, Class expectedClass)
{
    NSData *data = [defaults dataForKey:key];
    if (!data) return nil;

    NSError *error = nil;
    id value = nil;
    @try {
        value = [NSKeyedUnarchiver unarchivedObjectOfClass:expectedClass fromData:data error:&error];
    } @catch (NSException *exception) {
        value = nil;
    }
    if (value) return value;

    @try {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        value = [NSUnarchiver unarchiveObjectWithData:data];
#pragma clang diagnostic pop
    } @catch (NSException *exception) {
        return nil;
    }
    if (![value isKindOfClass:expectedClass]) return nil;

    NSData *updated = [NSKeyedArchiver archivedDataWithRootObject:value
                                           requiringSecureCoding:YES error:&error];
    if (updated) [defaults setObject:updated forKey:key];
    return value;
}

static inline void COWriteArchivedSetting(NSUserDefaults *defaults, NSString *key, id value)
{
    NSError *error = nil;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:value
                                       requiringSecureCoding:YES error:&error];
    if (data) [defaults setObject:data forKey:key];
}
