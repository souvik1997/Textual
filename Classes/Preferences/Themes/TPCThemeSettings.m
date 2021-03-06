/* ********************************************************************* 
                  _____         _               _
                 |_   _|____  _| |_ _   _  __ _| |
                   | |/ _ \ \/ / __| | | |/ _` | |
                   | |  __/>  <| |_| |_| | (_| | |
                   |_|\___/_/\_\\__|\__,_|\__,_|_|

 Copyright (c) 2010 - 2015 Codeux Software, LLC & respective contributors.
        Please see Acknowledgements.pdf for additional information.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of Textual and/or "Codeux Software, LLC", nor the 
      names of its contributors may be used to endorse or promote products 
      derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 SUCH DAMAGE.

 *********************************************************************** */

NS_ASSUME_NONNULL_BEGIN

#define _templateEngineVersionMaximum			3
#define _templateEngineVersionMinimum			3

@interface TPCThemeSettings ()
@property (nonatomic, assign, readwrite) BOOL invertSidebarColors;
@property (nonatomic, assign, readwrite) BOOL js_postHandleEventNotifications;
@property (nonatomic, assign, readwrite) BOOL js_postPreferencesDidChangesNotifications;
@property (nonatomic, assign, readwrite) BOOL usesIncompatibleTemplateEngineVersion;
@property (nonatomic, copy, readwrite, nullable) NSFont *themeChannelViewFont;
@property (nonatomic, copy, readwrite, nullable) NSString *themeNicknameFormat;
@property (nonatomic, copy, readwrite, nullable) NSString *themeTimestampFormat;
@property (nonatomic, copy, readwrite, nullable) NSString *settingsKeyValueStoreName;
@property (nonatomic, copy, readwrite, nullable) NSColor *underlyingWindowColor;
@property (nonatomic, assign, readwrite) double indentationOffset;
@property (nonatomic, assign, readwrite) TPCThemeSettingsNicknameColorStyle nicknameColorStyle;
@property (nonatomic, strong) GRMustacheTemplateRepository *styleTemplateRepository;
@property (nonatomic, strong) GRMustacheTemplateRepository *appTemplateRepository;
@end

@implementation TPCThemeSettings

#pragma mark -
#pragma mark Setting Loaders

- (nullable NSString *)_stringForKey:(NSString *)key fromDictionary:(NSDictionary<NSString *, id> *)dic
{
	NSParameterAssert(key != nil);
	NSParameterAssert(dic != nil);

	NSString *stringValue = [dic stringForKey:key];

	/* An empty string should not be considered a valid value */
	if (stringValue.length == 0) {
		return nil;
	}

	return stringValue;
}

- (nullable NSColor *)_colorForKey:(NSString *)key fromDictionary:(NSDictionary<NSString *, id> *)dic
{
	NSParameterAssert(key != nil);
	NSParameterAssert(dic != nil);

	NSString *colorValue = [dic stringForKey:key];

	/* Supported format: #FFF or #FFFFFF */
	if (colorValue.length != 4 && colorValue.length != 7) {
		return nil;
	}

	return [NSColor colorWithHexadecimalValue:colorValue];
}

- (nullable NSFont *)_fontForKey:(NSString *)key fromDictionary:(NSDictionary<NSString *, id> *)dic
{
	NSParameterAssert(key != nil);
	NSParameterAssert(dic != nil);

	NSDictionary<NSString *, id> *fontDictionary = [dic dictionaryForKey:key];

	if (fontDictionary == nil) {
		return nil;
	}

	NSString *fontName = [fontDictionary stringForKey:@"Font Name"];

	if (fontName == nil || [NSFont fontIsAvailable:fontName] == NO) {
		return nil;
	}

	CGFloat fontSize = [fontDictionary doubleForKey:@"Font Size"];

	if (fontSize < 5.0) {
		return nil;
	}

	return [NSFont fontWithName:fontName size:fontSize];
}

#pragma mark -
#pragma mark Template Handle

- (NSString *)templateNameWithLineType:(TVCLogLineType)type
{
	NSParameterAssert(type != TVCLogLineUndefinedType);

	NSString *typeString = [TVCLogLine stringForLineType:type];

	return [@"Line Types/" stringByAppendingString:typeString];
}

- (nullable GRMustacheTemplate *)templateWithLineType:(TVCLogLineType)type
{
	NSString *templateName = [self templateNameWithLineType:type];

	return [self templateWithName:templateName];
}

- (nullable GRMustacheTemplate *)templateWithName:(NSString *)templateName
{
	NSParameterAssert(templateName != nil);

	NSError *loadError = nil;

	GRMustacheTemplate *template = [self.styleTemplateRepository templateNamed:templateName error:&loadError];

	if (loadError && (loadError.code == GRMustacheErrorCodeTemplateNotFound || loadError.code == 260)) {
		loadError = nil;

		template = [self.appTemplateRepository templateNamed:templateName error:&loadError];
	}

	if (loadError) {
		LogToConsoleError("Failed to load template '%{public}@' with error: '%{public}@'",
			templateName, [loadError localizedDescription])
		LogToConsoleCurrentStackTrace
	}

	return template;
}

#pragma mark -
#pragma mark Style Settings

- (nullable NSString *)_keyValueStoreName
{
	NSString *storeName = self.settingsKeyValueStoreName;
	
	if (storeName.length == 0) {
		return nil;
	}

	return [NSString stringWithFormat:@"Internal Theme Settings Key-value Store -> %@", storeName];
}

- (nullable id)styleSettingsRetrieveValueForKey:(NSString *)key error:(NSString * _Nullable *)resultError
{
	if (key == nil || key.length == 0) {
		if ( resultError) {
			*resultError = @"Empty key value";
		}

		return nil;
	}

	NSString *storeKey = [self _keyValueStoreName];
	
	if (storeKey == nil) {
		if ( resultError) {
			*resultError = @"Empty key-value store name in styleSettings.plist — Set the key \"Key-value Store Name\" in styleSettings.plist as a string. The current style name is the recommended value.";
		}

		return nil;
	}

	NSDictionary *styleSettings = [RZUserDefaults() dictionaryForKey:storeKey];

	if (styleSettings == nil) {
		return nil;
	}

	return styleSettings[key];
}

- (BOOL)styleSettingsSetValue:(nullable id)objectValue forKey:(NSString *)objectKey error:(NSString * _Nullable *)resultError
{
	if (objectKey == nil || objectKey.length <= 0) {
		if (resultError) {
			*resultError = @"Empty key value";
		}

		return NO;
	}

	NSString *storeKey = [self _keyValueStoreName];
		
	if (storeKey == nil) {
		if (resultError) {
			*resultError = @"Empty key-value store name in styleSettings.plist — Set the key \"Key-value Store Name\" in styleSettings.plist as a string. The current style name is the recommended value.";
		}

		return NO;
	}

	BOOL removeValue = ( objectValue == nil ||
						[objectValue isKindOfClass:[NSNull class]] ||
						[objectValue isKindOfClass:[WebUndefined class]]);
	
	NSDictionary *styleSettings = [RZUserDefaults() dictionaryForKey:storeKey];

	NSMutableDictionary<NSString *, id> *styleSettingsMutable = nil;

	if (styleSettings == nil) {
		if (removeValue) {
			return YES;
		}
		
		styleSettingsMutable = [NSMutableDictionary dictionaryWithCapacity:1];
	} else {
		styleSettingsMutable = [styleSettings mutableCopy];
	}
	
	if (removeValue) {
		[styleSettingsMutable removeObjectForKey:objectKey];
	} else {
		styleSettingsMutable[objectKey] = objectValue;
	}

	[RZUserDefaults() setObject:[styleSettingsMutable copy] forKey:storeKey];
		
	return YES;
}

#pragma mark -
#pragma mark Load Settings

- (void)loadApplicationTemplateRespository:(NSUInteger)version
{
	NSString *filename = [NSString stringWithFormat:@"/Style Default Templates/Version %lu/", version];

	NSString *templatesPath = [[TPCPathInfo applicationResourcesFolderPath] stringByAppendingPathComponent:filename];

	NSURL *templatesPathURL = [NSURL fileURLWithPath:templatesPath isDirectory:YES];

	self.appTemplateRepository = [GRMustacheTemplateRepository templateRepositoryWithBaseURL:templatesPathURL];

	NSAssert((self.appTemplateRepository != nil),
		@"Default template repository not found");
}

- (void)reloadWithPath:(NSString *)path
{
	NSParameterAssert(path != nil);

	/* Load any custom templates */
	NSString *templatesPath = [path stringByAppendingPathComponent:@"/Data/Templates"];

	NSURL *templatesPathURL = [NSURL fileURLWithPath:templatesPath isDirectory:YES];

	self.styleTemplateRepository = [GRMustacheTemplateRepository templateRepositoryWithBaseURL:templatesPathURL];

	/* Reset properties */
	self.themeChannelViewFont = nil;

	self.themeNicknameFormat = nil;
	self.themeTimestampFormat = nil;

	self.settingsKeyValueStoreName = nil;

	self.invertSidebarColors = NO;

	self.underlyingWindowColor = nil;

	self.indentationOffset = TPCThemeSettingsDisabledIndentationOffset;

	self.usesIncompatibleTemplateEngineVersion = YES;

	/* Load style settings dictionary */
	NSUInteger templateEngineVersion = 0;

	NSString *settingsPath = [path stringByAppendingPathComponent:@"/Data/Settings/styleSettings.plist"];

	NSDictionary<NSString *, id> *styleSettings = [NSDictionary dictionaryWithContentsOfFile:settingsPath];

	if (styleSettings) {
		self.themeChannelViewFont = [self _fontForKey:@"Override Channel Font" fromDictionary:styleSettings];

		self.themeNicknameFormat = [self _stringForKey:@"Nickname Format" fromDictionary:styleSettings];
		self.themeTimestampFormat = [self _stringForKey:@"Timestamp Format" fromDictionary:styleSettings];

		self.invertSidebarColors = [styleSettings boolForKey:@"Force Invert Sidebars"];

		self.underlyingWindowColor = [self _colorForKey:@"Underlying Window Color" fromDictionary:styleSettings];

		self.settingsKeyValueStoreName = [self _stringForKey:@"Key-value Store Name" fromDictionary:styleSettings];

		self.js_postHandleEventNotifications = [styleSettings boolForKey:@"Post Textual.handleEvent() Notifications"];
		self.js_postPreferencesDidChangesNotifications = [styleSettings boolForKey:@"Post Textual.preferencesDidChange() Notifications"];

		/* Disable indentation? */
		id indentationOffset = [styleSettings objectForKey:@"Indentation Offset"];

		if (indentationOffset == nil) {
			self.indentationOffset = TPCThemeSettingsDisabledIndentationOffset;
		} else {
			double indentationOffsetDouble = [indentationOffset doubleValue];

			if (indentationOffsetDouble < 0.0) {
				self.indentationOffset = TPCThemeSettingsDisabledIndentationOffset;
			} else {
				self.indentationOffset = indentationOffsetDouble;
			}
		}

		/* Nickname color style */
		id nicknameColorStyle = [styleSettings objectForKey:@"Nickname Color Style"];

		BOOL computeRGBValue = [TPCPreferences nicknameColorHashingComputesRGBValue];

		if (computeRGBValue && NSObjectsAreEqual(nicknameColorStyle, @"HSL-light")) {
			self.nicknameColorStyle = TPCThemeSettingsNicknameColorHashHueLightStyle;
		} else if (computeRGBValue && NSObjectsAreEqual(nicknameColorStyle, @"HSL-dark")) {
			self.nicknameColorStyle = TPCThemeSettingsNicknameColorHashHueDarkStyle;
		} else {
			self.nicknameColorStyle = TPCThemeSettingsNicknameColorLegacyStyle;
		}

		/* Get style template version */
		NSDictionary<NSString *, NSNumber *> *templateVersions = [styleSettings dictionaryForKey:@"Template Engine Versions"];

		{
			NSString *applicationVersion = [TPCApplicationInfo applicationVersionShort];

			NSUInteger targetVersion = [templateVersions unsignedIntegerForKey:applicationVersion];

			if (NSNumberInRange(targetVersion, _templateEngineVersionMinimum, _templateEngineVersionMaximum)) {
				templateEngineVersion = targetVersion;

				self.usesIncompatibleTemplateEngineVersion = NO;
			}
		}

		if (templateEngineVersion == 0) {
			NSUInteger defaultVersion = [templateVersions unsignedIntegerForKey:@"default"];

			if (NSNumberInRange(defaultVersion, _templateEngineVersionMinimum, _templateEngineVersionMaximum)) {
				templateEngineVersion = defaultVersion;

				self.usesIncompatibleTemplateEngineVersion = NO;
			}
		}
	}

	if (templateEngineVersion == 0) {
		templateEngineVersion = _templateEngineVersionMaximum;
	}

	/* Fall back to the default repository */
	[self loadApplicationTemplateRespository:templateEngineVersion];;

	/* Inform our defaults controller about a few overrides. */
	/* These setValue calls basically tell the NSUserDefaultsController for the "Preferences" 
	 window that the active theme has overrode a few user configurable options. The window then 
	 blanks out the options specified to prevent the user from modifying. */
	[TPCPreferences setInvertSidebarColorsPreferenceUserConfigurable:(self.invertSidebarColors == NO)];

	[TPCPreferences setThemeChannelViewFontPreferenceUserConfigurable:(self.themeChannelViewFont == nil)];

	[TPCPreferences setThemeNicknameFormatPreferenceUserConfigurable:NSObjectIsEmpty(self.themeNicknameFormat)];

	[TPCPreferences setThemeTimestampFormatPreferenceUserConfigurable:NSObjectIsEmpty(self.themeTimestampFormat)];
}

@end

NS_ASSUME_NONNULL_END
