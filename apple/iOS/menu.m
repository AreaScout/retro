/*  RetroArch - A frontend for libretro.
 *  Copyright (C) 2013 - Jason Fetters
 * 
 *  RetroArch is free software: you can redistribute it and/or modify it under the terms
 *  of the GNU General Public License as published by the Free Software Found-
 *  ation, either version 3 of the License, or (at your option) any later version.
 *
 *  RetroArch is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
 *  without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
 *  PURPOSE.  See the GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License along with RetroArch.
 *  If not, see <http://www.gnu.org/licenses/>.
 */

#include <objc/runtime.h>
#include "apple/common/RetroArch_Apple.h"
#include "menu.h"

/*********************************************/
/* RAMenuBase                                */
/* A menu class that displays RAMenuItemBase */
/* objects.                                  */
/*********************************************/
@implementation RAMenuBase

- (id)initWithStyle:(UITableViewStyle)style
{
   return [super initWithStyle:style];
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
   return [[self itemForIndexPath:indexPath] cellForTableView:tableView];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
   [[self itemForIndexPath:indexPath] wasSelectedOnTableView:tableView ofController:self];
}

@end

/*********************************************/
/* RAMenuItemBasic                           */
/* A simple menu item that displays a text   */
/* description and calls a block object when */
/* selected.                                 */
/*********************************************/
@implementation RAMenuItemBasic

+ (RAMenuItemBasic*)itemWithDescription:(NSString*)description action:(void (^)())action
{
   return [self itemWithDescription:description action:action detail:Nil];
}

+ (RAMenuItemBasic*)itemWithDescription:(NSString*)description action:(void (^)())action detail:(NSString* (^)())detail
{
   return [self itemWithDescription:description association:nil action:action detail:detail];
}

+ (RAMenuItemBasic*)itemWithDescription:(NSString*)description association:(id)userdata action:(void (^)())action detail:(NSString* (^)())detail
{
   RAMenuItemBasic* item = [RAMenuItemBasic new];
   item.description = description;
   item.userdata = userdata;
   item.action = action;
   item.detail = detail;
   return item;
}

- (UITableViewCell*)cellForTableView:(UITableView*)tableView
{
   static NSString* const cell_id = @"text";
   
   UITableViewCell* result = [tableView dequeueReusableCellWithIdentifier:cell_id];
   if (!result)
      result = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cell_id];
   
   result.textLabel.text = self.description;
   result.detailTextLabel.text = self.detail ? self.detail(self.userdata) : nil;
   return result;
}

- (void)wasSelectedOnTableView:(UITableView*)tableView ofController:(UIViewController*)controller
{
   if (self.action)
      self.action(self.userdata);
}

@end

/*********************************************/
/* RAMenuItemBoolean                         */
/* A simple menu item that displays the      */
/* state, and allows editing, of a boolean   */
/* setting.                                  */
/*********************************************/
@implementation RAMenuItemBoolean

+ (RAMenuItemBoolean*)itemForSetting:(const char*)setting_name
{
   RAMenuItemBoolean* item = [RAMenuItemBoolean new];
   item.setting = setting_data_find_setting(setting_name);
   return item;
}

- (UITableViewCell*)cellForTableView:(UITableView*)tableView
{
   static NSString* const cell_id = @"boolean_setting";
   
   UITableViewCell* result = [tableView dequeueReusableCellWithIdentifier:cell_id];
   if (!result)
   {
      result = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cell_id];
      result.selectionStyle = UITableViewCellSelectionStyleNone;
      result.accessoryView = [UISwitch new];
   }

   result.textLabel.text = @(self.setting->short_description);
   [(id)result.accessoryView removeTarget:nil action:NULL forControlEvents:UIControlEventValueChanged];
   [(id)result.accessoryView addTarget:self action:@selector(handleBooleanSwitch:) forControlEvents:UIControlEventValueChanged];
   
   if (self.setting)
      [(id)result.accessoryView setOn:*self.setting->value.boolean];
   return result;
}

- (void)handleBooleanSwitch:(UISwitch*)swt
{
   if (self.setting)
      *self.setting->value.boolean = swt.on ? true : false;
}

- (void)wasSelectedOnTableView:(UITableView*)tableView ofController:(UIViewController*)controller
{
}

@end

/*********************************************/
/* RAMenuItemString                          */
/* A simple menu item that displays the      */
/* state, and allows editing, of a string or */
/* numeric setting.                          */
/*********************************************/
@implementation RAMenuItemString

+ (RAMenuItemString*)itemForSetting:(const char*)setting_name
{
   RAMenuItemString* item = [RAMenuItemString new];
   item.setting = setting_data_find_setting(setting_name);
   return item;
}

- (UITableViewCell*)cellForTableView:(UITableView*)tableView
{
   static NSString* const cell_id = @"string_setting";

   self.parentTable = tableView;

   UITableViewCell* result = [tableView dequeueReusableCellWithIdentifier:cell_id];
   if (!result)
   {
      result = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cell_id];
      result.selectionStyle = UITableViewCellSelectionStyleNone;
   }

   char buffer[256];
   result.textLabel.text = @(self.setting->short_description);

   if (self.setting)
      result.detailTextLabel.text = @(setting_data_get_string_representation(self.setting, buffer, sizeof(buffer)));
   return result;
}

- (void)wasSelectedOnTableView:(UITableView*)tableView ofController:(UIViewController*)controller
{
   UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:@"Enter new value" message:@(self.setting->short_description) delegate:self
                                                  cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK", nil];
   alertView.alertViewStyle = UIAlertViewStylePlainTextInput;

   UITextField* field = [alertView textFieldAtIndex:0];
   char buffer[256];
   
   field.delegate = self;
   field.text = @(setting_data_get_string_representation(self.setting, buffer, sizeof(buffer)));
   field.keyboardType = (self.setting->type == ST_INT || self.setting->type == ST_FLOAT) ? UIKeyboardTypeDecimalPad : UIKeyboardTypeDefault;

   [alertView show];
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
   if (self.setting->type == ST_INT || self.setting->type == ST_FLOAT)
   {
      RANumberFormatter* formatter = [[RANumberFormatter alloc] initWithFloatSupport:self.setting->type == ST_FLOAT
                                                                minimum:self.setting->min maximum:self.setting->max];

      NSString* result = [textField.text stringByReplacingCharactersInRange:range withString:string];
      return [formatter isPartialStringValid:result newEditingString:nil errorDescription:nil];
   }

   return YES;
}

- (void)alertView:(UIAlertView*)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
   NSString* text = [alertView textFieldAtIndex:0].text;

   if (buttonIndex == alertView.firstOtherButtonIndex && text.length)
   {
      setting_data_set_with_string_representation(self.setting, text.UTF8String);
      [self.parentTable reloadData];
   }
}

@end

/*********************************************/
/* RAMenuItemPathSetting                     */
/* A menu item that displays and allows      */
/* browsing for a path setting.              */
/*********************************************/
@implementation RAMenuItemPathSetting

+ (RAMenuItemPathSetting*)itemForSetting:(const char*)setting_name
{
   RAMenuItemPathSetting* item = [RAMenuItemPathSetting new];
   item.setting = setting_data_find_setting(setting_name);
   return item;
}

- (void)wasSelectedOnTableView:(UITableView*)tableView ofController:(UIViewController*)controller
{
   RADirectoryList* list = [[RADirectoryList alloc] initWithPath:@"/" delegate:self];
   [controller.navigationController pushViewController:list animated:YES];
}

- (bool)directoryList:(id)list itemWasSelected:(RADirectoryItem *)path
{
   setting_data_set_with_string_representation(self.setting, path.path.UTF8String);
   [[list navigationController] popViewControllerAnimated:YES];
      
   [self.parentTable reloadData];

   return true;
}

@end


/*********************************************/
/* RAMainMenu                                */
/* Menu object that is displayed immediately */
/* after startup.                            */
/*********************************************/
@interface RAMainMenu()
@property bool useAutoDetect;
@end

@implementation RAMainMenu

- (id)init
{
   if ((self = [super initWithStyle:UITableViewStylePlain]))
   {
      RAMainMenu* __weak weakSelf = self;
   
      self.title = @"RetroArch";
   
      self.sections =
      (id)@[
         @[ @"",
            [RAMenuItemBasic itemWithDescription:@"Choose Core"
               action:^{ weakSelf.useAutoDetect = false; [self chooseCore]; }
               detail:^{ return weakSelf.core ? apple_get_core_display_name(self.core) : @"None Selected"; }],
            [RAMenuItemBasic itemWithDescription:@"Load Game (Core)"          action:^{ weakSelf.useAutoDetect = false; [weakSelf loadGame]; }],
            [RAMenuItemBasic itemWithDescription:@"Load Game (History)"       action:^{ [weakSelf loadHistory]; }],
            [RAMenuItemBasic itemWithDescription:@"Load Game (Detect Core)"   action:^{ weakSelf.useAutoDetect = true;  [weakSelf loadGame]; }],
            [RAMenuItemBasic itemWithDescription:@"Settings"                  action:^{ [weakSelf showSettings]; }]
         ]
      ];
   }
   
   return self;
}

- (void)chooseCore
{
   [self.navigationController pushViewController:[[RACoreList alloc] initWithGame:nil delegate:self] animated:YES];
}

- (void)loadGame
{
   NSString* rootPath = RetroArch_iOS.get.documentsDirectory;
   NSString* ragPath = [rootPath stringByAppendingPathComponent:@"RetroArchGames"];
   NSString* target = path_is_directory(ragPath.UTF8String) ? ragPath : rootPath;

   [self.navigationController pushViewController:[[RADirectoryList alloc] initWithPath:target delegate:self] animated:YES];
}

- (void)loadHistory
{
   NSString* history_path = [NSString stringWithFormat:@"%@/%s", RetroArch_iOS.get.systemDirectory, ".retroarch-game-history.txt"];
   [self.navigationController pushViewController:[[RAHistoryMenu alloc] initWithHistoryPath:history_path] animated:YES];
}

- (void)showSettings
{
   [self.navigationController pushViewController:[RAFrontendSettingsMenu new] animated:YES];
}

- (bool)coreList:(id)list itemWasSelected:(NSString*)module
{
   self.core = module;
   [self.tableView reloadData];
   
   if (!self.useAutoDetect)
      [self.navigationController popViewControllerAnimated:YES];
   else
      apple_run_core(self.core, self.path.UTF8String);

   return true;
}

- (bool)directoryList:(id)list itemWasSelected:(RADirectoryItem*)path
{
   if (!path.isDirectory)
   {
      self.path = path.path;
      
      if (!self.useAutoDetect)
         apple_run_core(self.core, self.path.UTF8String);
      else
         [self.navigationController pushViewController:[[RACoreList alloc] initWithGame:path.path delegate:self] animated:YES];
   }

   return true;
}

@end

/*********************************************/
/* RAHistoryMenu                             */
/* Menu object that displays and allows      */
/* launching a file from the ROM history.    */
/*********************************************/
static const char* get_history_index_path(rom_history_t* history, uint32_t index)
{
   const char *path, *core_path, *core_name;
   rom_history_get_index(history, index, &path, &core_path, &core_name);
   return path ? path : "";
}

static const char* get_history_index_core_path(rom_history_t* history, uint32_t index)
{
   const char *path, *core_path, *core_name;
   rom_history_get_index(history, index, &path, &core_path, &core_name);
   return core_path ? core_path : "";
}

static const char* get_history_index_core_name(rom_history_t* history, uint32_t index)
{
   const char *path, *core_path, *core_name;
   rom_history_get_index(history, index, &path, &core_path, &core_name);
   return core_name ? core_name : "";
}

@implementation RAHistoryMenu

- (id)initWithHistoryPath:(NSString *)historyPath
{
   if ((self = [super initWithStyle:UITableViewStylePlain]))
   {
      RAHistoryMenu* __weak weakSelf = self;
   
      _history = rom_history_init(historyPath.UTF8String, 100);

      NSMutableArray* section = [NSMutableArray arrayWithObject:@""];
      [self.sections addObject:section];
      
      for (int i = 0; _history && i != rom_history_size(_history); i ++)
      {
         RAMenuItemBasic* item = [RAMenuItemBasic itemWithDescription:@(path_basename(get_history_index_path(weakSelf.history, i)))
                                                  action:^{ apple_run_core(@(get_history_index_core_path(weakSelf.history, i)),
                                                                             get_history_index_path(weakSelf.history, i)); }
                                                  detail:^{ return @(get_history_index_core_name(weakSelf.history, i)); }];
         [section addObject:item];
      }
   }
   
   return self;
}

- (void)dealloc
{
   rom_history_free(self.history);
}

@end

/*********************************************/
/* RAFrontendSettingsMenu                    */
/* Menu object that displays and allows      */
/* editing of cocoa frontend related         */
/* settings.                                 */
/*********************************************/
static const void* const associated_core_key = &associated_core_key;

@implementation RAFrontendSettingsMenu

- (id)init
{
   if ((self = [super initWithStyle:UITableViewStyleGrouped]))
   {
      RAFrontendSettingsMenu* __weak weakSelf = self;
   
      NSMutableArray* cores = [NSMutableArray arrayWithObject:@"Cores"];
      [cores addObject:[RAMenuItemBasic itemWithDescription:@"Global Core Config"
         action: ^{ [weakSelf showCoreConfigFor:nil]; }]];

      const core_info_list_t* core_list = apple_core_info_list_get();
      for (int i = 0; i < core_list->count; i ++)
         [cores addObject:[RAMenuItemBasic itemWithDescription:@(core_list->list[i].display_name)
            association:apple_get_core_id(&core_list->list[i])
            action: ^(id userdata) { [weakSelf showCoreConfigFor:userdata]; }
            detail: ^(id userdata) { return apple_core_info_has_custom_config([userdata UTF8String]) ? @"[Custom]" : @"[Global]"; }]];
  
      self.sections =
      (id)@[
         @[ @"Frontend",
            [RAMenuItemBasic itemWithDescription:@"Diagnostic Log"
               action: ^{ [weakSelf.navigationController pushViewController:[RALogView new] animated:YES]; }],
            [RAMenuItemBasic itemWithDescription:@"TV Mode" action:^{ }]
         ],
         
         @[ @"Bluetooth",
            [RAMenuItemBasic itemWithDescription:@"Mode" action:^{ }]
         ],
         
         @[ @"Orientations",
            [RAMenuItemBasic itemWithDescription:@"Portrait" action:^{ }],
            [RAMenuItemBasic itemWithDescription:@"Portrait Upside Down" action:^{ }],
            [RAMenuItemBasic itemWithDescription:@"Landscape Left" action:^{ }],
            [RAMenuItemBasic itemWithDescription:@"Landscape Right" action:^{ }]
         ],
         
         cores
      ];
   }
   
   return self;
}

- (void)showCoreConfigFor:(NSString*)core
{
   if (core && !apple_core_info_has_custom_config(core.UTF8String))
   {
      UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"RetroArch"
                                                      message:@"No custom configuration for this core exists, "
                                                               "would you like to create one?"
                                                     delegate:self
                                            cancelButtonTitle:@"No"
                                            otherButtonTitles:@"Yes", nil];
      objc_setAssociatedObject(alert, associated_core_key, core, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
      [alert show];
   }
   else
      [self.navigationController pushViewController:[[RACoreSettingsMenu alloc] initWithCore:core] animated:YES];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
   NSString* core_id = objc_getAssociatedObject(alertView, associated_core_key);
   
   if (buttonIndex == alertView.firstOtherButtonIndex && core_id)
   {
      char path[PATH_MAX];
      apple_core_info_get_custom_config(core_id.UTF8String, path, sizeof(path));
   
      if (![[NSFileManager defaultManager] copyItemAtPath:apple_platform.globalConfigFile toPath:@(path) error:nil])
         RARCH_WARN("Could not create custom config at %s", path);
      [self.tableView reloadData];
   }

   [self.navigationController pushViewController:[[RACoreSettingsMenu alloc] initWithCore:core_id] animated:YES];
}

@end

/*********************************************/
/* RACoreSettingsMenu                        */
/* Menu object that displays and allows      */
/* editing of the setting_data list.         */
/*********************************************/
@interface RACoreSettingsMenu()
@property (nonatomic) NSString* pathToSave; // < Leave nil to not save
@end

@implementation RACoreSettingsMenu

- (id)initWithCore:(NSString*)core
{
   char buffer[PATH_MAX];

   RACoreSettingsMenu* __weak weakSelf = self;

   if ((self = [super initWithStyle:UITableViewStyleGrouped]))
   {
      if (apple_core_info_has_custom_config(core.UTF8String))
         _pathToSave = @(apple_core_info_get_custom_config(core.UTF8String, buffer, sizeof(buffer)));
      else
         _pathToSave = apple_platform.globalConfigFile;
      
      setting_data_reset();
      setting_data_load_config_path(_pathToSave.UTF8String);
      
      self.core = core;
      self.title = self.core ? apple_get_core_display_name(core) : @"Global Core Config";
   
      NSMutableArray* settings = [NSMutableArray arrayWithObjects:@"", nil];
      [self.sections addObject:settings];

      const rarch_setting_t* setting_data = setting_data_get_list();
      for (const rarch_setting_t* i = setting_data; i->type != ST_NONE; i ++)
         if (i->type == ST_GROUP)
            [settings addObject:[RAMenuItemBasic itemWithDescription:@(i->name) action:
            ^{
               [weakSelf.navigationController pushViewController:[[RACoreSettingsMenu alloc] initWithGroup:i] animated:YES];
            }]];
   }
   
   return self;
}

- (id)initWithGroup:(const rarch_setting_t*)group
{
   if ((self = [super initWithStyle:UITableViewStyleGrouped]))
   {
      self.title = @(group->name);
   
      NSMutableArray* settings = nil;
   
      for (const rarch_setting_t* i = group + 1; i->type != ST_END_GROUP; i ++)
      {
         if (i->type == ST_SUB_GROUP)
            settings = [NSMutableArray arrayWithObjects:@(i->name), nil];
         else if (i->type == ST_END_SUB_GROUP)
         {
            if (settings.count)
               [self.sections addObject:settings];
         }
         else if (i->type == ST_BOOL)
            [settings addObject:[RAMenuItemBoolean itemForSetting:i->name]];
         else if (i->type == ST_INT || i->type == ST_FLOAT || i->type == ST_STRING)
            [settings addObject:[RAMenuItemString itemForSetting:i->name]];
         else if (i->type == ST_PATH)
            [settings addObject:[RAMenuItemPathSetting itemForSetting:i->name]];
      }
   }

   return self;
}

- (void)dealloc
{
   if (self.pathToSave)
      setting_data_save_config_path(self.pathToSave.UTF8String);
}

@end
