// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#import <AppKit/NSPasteboard.h>

#include "nvim/types.h"
#include "nvim/memory.h"

// HACK: We need to avoid including nvim/normal.h because it transitively
//       includes nvim/api/private/defs.h which defines a Boolean type.
//       Unfortunately Apple's system headers define an incompatible Boolean
//       type with the same spelling. Instead of including nvim/normal.h, we
//       will duplicate the required definitions here. This shouldn't be too
//       much of a maintenance burden as the MotionType enum is stable.
typedef enum {
  kMTCharWise = 0,
  kMTLineWise = 1,
  kMTBlockWise = 2,
  kMTUnknown = -1
} MotionType;

// We also need to duplicate the definitions in nvim/os/clipboard.h.
// Note: These should remain in sync!
typedef struct {
  char_u *text;
  size_t length;
  MotionType regtype;
} ClipboardData;

bool clipboard_get(ClipboardData *data);

void clipboard_set(char regname, MotionType regtype,
                   char_u **lines, size_t numlines);

// This constant is shared with Vim to preserve copying and pasting
// compatibility. Do not change!
static NSString * const NVimPasteboardType = @"VimPboardType";

static inline void clear_clipboard_data(ClipboardData *data) {
  data->text = NULL;
  data->length = 0;
  data->regtype = kMTUnknown;
}

static bool set_clipboard_data(ClipboardData *data,
                               int regtype, NSString *string)
{
  if (regtype != kMTCharWise &&
      regtype != kMTLineWise &&
      regtype != kMTBlockWise) {
    regtype = kMTUnknown;
  }

  size_t length = [string lengthOfBytesUsingEncoding:NSUTF8StringEncoding];

  if (!length) {
    clear_clipboard_data(data);
    return true;
  }

  char_u *text = xmalloc(length + 1);
  BOOL converted = [string getCString:(char*)text
                            maxLength:length + 1
                             encoding:NSUTF8StringEncoding];

  if (!converted) {
    xfree(text);
    return false;
  }
  
  data->text = text;
  data->length = length;
  data->regtype = regtype;

  return true;
}

bool clipboard_get(ClipboardData *data)
{
  @autoreleasepool {
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    NSArray *supportedTypes = @[NVimPasteboardType, NSPasteboardTypeString];

    NSString *available = [pasteboard availableTypeFromArray:supportedTypes];

    if ([available isEqual:NVimPasteboardType]) {
      // This should be an array with two objects:
      //   1. Motion type (NSNumber)
      //   2. Text (NSString)
      //
      // If this is not the case we fall back on using NSPasteboardTypeString.
      NSArray *plist = [pasteboard propertyListForType:NVimPasteboardType];

      if ([plist isKindOfClass:[NSArray class]] && [plist count] == 2 &&
          [plist[0] isKindOfClass:[NSNumber class]] &&
          [plist[1] isKindOfClass:[NSString class]]) {
        return set_clipboard_data(data, [plist[0] intValue], plist[1]);
      }
    }

    NSString *string = [pasteboard stringForType:NSPasteboardTypeString];

    if (!string) {
      clear_clipboard_data(data);
      return true;
    }

    NSMutableString *mstring = [string mutableCopy];
    NSRange range = NSMakeRange(0, [string length]);

    // Replace unrecognized end-of-line sequences with \x0a (line feed)
    NSUInteger replaced = [mstring replaceOccurrencesOfString:@"\x0d\x0a"
                                                   withString:@"\x0a"
                                                      options:0
                                                        range:range];

    if (replaced == 0) {
      [mstring replaceOccurrencesOfString:@"\x0d"
                               withString:@"\x0a"
                                  options:0
                                    range:range];
    }

    return set_clipboard_data(data, kMTUnknown, mstring);
  }
}

void clipboard_set(char regname, MotionType regtype,
                   char_u **lines, size_t numlines)
{
  @autoreleasepool {
    // Unused on MacOS. No selection / clipboard distinction.
    (void)regname;
    
    NSMutableString *string =
      [[NSMutableString alloc] initWithCapacity:numlines * 80];
    
    for (size_t i=0; i<numlines; ++i) {
      NSString *line = [NSString stringWithUTF8String:(const char*)lines[i]];
      [string appendString:line];
      [string appendString:@"\n"];
    }
    
    // Remove the trailing new line character in character wise yanks
    if (regtype == kMTCharWise) {
      [string deleteCharactersInRange:NSMakeRange([string length] - 1,1)];
    }
    
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    NSArray *supportedTypes = @[NVimPasteboardType, NSPasteboardTypeString];
    NSArray *plist = @[[NSNumber numberWithInt:regtype], string];

    [pasteboard declareTypes:supportedTypes owner:nil];
    [pasteboard setPropertyList:plist forType:NVimPasteboardType];
    [pasteboard setString:string forType:NSPasteboardTypeString];
  }
}

