/*
This file is part of GameHub.
Copyright (C) 2018 Anatoliy Kashkin

GameHub is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

GameHub is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with GameHub.  If not, see <https://www.gnu.org/licenses/>.
*/

using Gtk;
using Granite;

using GameHub.Data;
using GameHub.Utils;

using GameHub.UI.Widgets;

using GameHub.Data.DB;

namespace GameHub.UI.Dialogs.SettingsDialog.Tabs
{
	public class Emulators: SettingsDialogTab
	{
		private Stack stack;
		private Button add_btn;
		private Button remove_btn;

		private EmulatorPage? previous_page;

		public Emulators(SettingsDialog dlg)
		{
			Object(orientation: Orientation.HORIZONTAL, dialog: dlg);
		}

		construct
		{
			margin_start = margin_end = 0;

			var paths = FSUtils.Paths.Settings.get_instance();

			stack = new Stack();
			stack.margin_start = stack.margin_end = 8;
			stack.expand = true;
			stack.set_size_request(360, 240);

			var sidebar_box = new Box(Orientation.VERTICAL, 0);
			sidebar_box.vexpand = true;

			var sidebar = new StackSidebar();
			sidebar.stack = stack;
			sidebar.get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);
			sidebar.vexpand = true;
			sidebar.set_size_request(128, -1);

			var actionbar = new ActionBar();
			actionbar.vexpand = false;
			actionbar.get_style_context().add_class(Gtk.STYLE_CLASS_INLINE_TOOLBAR);

			add_btn = new Button.from_icon_name("list-add-symbolic", IconSize.MENU);
			add_btn.get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);

			remove_btn = new Button.from_icon_name("list-remove-symbolic", IconSize.MENU);
			remove_btn.get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);

			var actions = new Box(Orientation.HORIZONTAL, 0);
			actions.get_style_context().add_class(Gtk.STYLE_CLASS_LINKED);

			actions.add(add_btn);
			actions.add(remove_btn);

			actionbar.pack_start(actions);

			sidebar_box.add(sidebar);
			sidebar_box.add(actionbar);

			add(sidebar_box);
			add(new Separator(Orientation.VERTICAL));
			add(stack);

			stack.notify["visible-child"].connect(() => {
				var page = stack.visible_child as EmulatorPage;
				if(previous_page != null && previous_page != page)
				{
					previous_page.save();
				}
				previous_page = page;
			});

			dialog.destroy.connect(() => {
				if(previous_page != null)
				{
					previous_page.save();
				}
			});

			add_btn.clicked.connect(() => {
				add_emu_page();
			});

			remove_btn.clicked.connect(() => {
				remove_emu_page();
			});

			var emulators = Tables.Emulators.get_all();
			foreach(var emu in emulators)
			{
				add_emu_page(emu);
			}
		}

		private void add_emu_page(Emulator? emulator=null)
		{
			var page = new EmulatorPage(stack, emulator);
			var id = emulator != null ? "emu/" + emulator.id : stack.get_children().length().to_string();
			stack.add_titled(page, id, emulator != null ? emulator.name : "");
			page.show_all();
			if(emulator == null)
			{
				stack.set_visible_child(page);
			}
			page.emulator.removed.connect(() => {
				stack.remove(page);
				remove_btn.sensitive = stack.get_children().length() > 0;
			});
			remove_btn.sensitive = stack.get_children().length() > 0;
		}

		private void remove_emu_page()
		{
			var page = stack.visible_child as EmulatorPage;
			if(page != null)
			{
				page.remove();
			}
		}

		private class EmulatorPage: Grid
		{
			private string _title;
			public string title
			{
				get
				{
					return _title;
				}
				set
				{
					_title = value.strip();
					if(parent == stack)
					{
						stack.child_set(this, title: _title);
					}
				}
			}
			public Stack stack { get; construct; }
			public Emulator emulator { get; construct set; }

			private int rows = 0;

			private Granite.Widgets.ModeButton mode;

			private new Entry name;
			private FileChooserButton emudir;
			private FileChooserButton executable;
			private Label executable_label;
			private Entry arguments;
			private Label arguments_label;

			public EmulatorPage(Stack stack, Emulator? emulator=null)
			{
				Object(orientation: Orientation.VERTICAL, stack: stack, emulator: emulator ?? new Emulator.empty());
			}

			construct
			{
				row_spacing = 4;
				column_spacing = 8;

				mode = new Granite.Widgets.ModeButton();
				mode.margin_bottom = 8;
				mode.halign = Align.CENTER;
				mode.append_text(_("Executable"));
				mode.append_text(_("Installer"));
				mode.selected = 0;
				attach(mode, 0, rows, 2, 1);
				rows++;

				name = add_entry(_("Name"), "insert-text-symbolic", true);

				name.text = emulator.name ?? "";

				name.changed.connect(() => {
					title = name.text.strip();
					Tables.Emulators.remove(emulator);
					emulator.name = title;
				});

				name.changed();

				add_separator();

				executable = add_filechooser(_("Executable"), _("Select executable"), FileChooserAction.OPEN, true, out executable_label);

				arguments = add_entry(_("Arguments"), "utilities-terminal-symbolic", false, out arguments_label);

				arguments.text = emulator.arguments ?? "$file $game_args";

				arguments.changed.connect(() => {
					emulator.arguments = arguments.text.strip();
				});

				arguments.changed();

				add_separator();

				emudir = add_filechooser(_("Directory"), _("Select emulator directory"), FileChooserAction.SELECT_FOLDER, true);

				executable.file_set.connect(() => {
					emulator.executable = executable.get_file();
					if(name.text.strip().length == 0)
					{
						name.text = executable.get_file().get_basename();
					}
					update();
				});

				if(emulator.executable != null && emulator.executable.query_exists())
				{
					try
					{
						executable.set_file(emulator.executable);
						executable.file_set();
					}
					catch(Error e)
					{
						warning(e.message);
					}
				}

				add_separator();

				var compat_force_switch = add_switch(_("Force compatibility mode"), emulator.force_compat, f => { emulator.force_compat = f; });
				compat_force_switch.no_show_all = true;

				var compat_tool = new CompatToolPicker(emulator, false);
				compat_tool.no_show_all = true;
				attach(compat_tool, 0, rows, 2, 1);
				rows++;

				emulator.notify["use-compat"].connect(() => {
					compat_force_switch.visible = !emulator.needs_compat;
					compat_tool.visible = emulator.use_compat;
				});

				mode.mode_changed.connect(update);

				update();
			}

			private void update()
			{
				if(mode.selected == 0 && executable.get_file() != null && emudir.get_file() == null)
				{
					try
					{
						emudir.select_file(executable.get_file().get_parent());
					}
					catch(Error e)
					{
						warning(e.message);
					}
				}

				emulator.name = title;
				emulator.arguments = arguments.text.strip();

				emulator.install_dir = emudir.get_file();

				executable_label.label = mode.selected == 0 ? _("Executable") : _("Installer");
				arguments.sensitive = arguments_label.sensitive = mode.selected == 0;

				emulator.notify_property("use-compat");
			}

			public void save()
			{
				update();

				if(mode.selected == 1 && executable.get_file() != null && emudir.get_file() != null)
				{
					sensitive = false;

					emulator.installer = new Emulator.Installer(emulator, emulator.executable);

					emulator.executable = null;
					emulator.install.begin((obj, res) => {
						emulator.install.end(res);
						sensitive = true;
						mode.selected = 0;
						try
						{
							executable.select_file(emulator.executable);
						}
						catch(Error e)
						{
							warning(e.message);
						}
						emulator.save();
					});

					return;
				}

				emulator.save();
			}

			public new void remove()
			{
				emulator.remove();
			}

			private Entry add_entry(string text, string icon, bool required=true, out Label label=null)
			{
				label = new Label(text);
				label.halign = Align.START;
				label.xalign = 1;
				label.margin = 4;
				if(required)
				{
					label.get_style_context().add_class("category-label");
				}
				var entry = new Entry();
				entry.primary_icon_name = icon;
				entry.primary_icon_activatable = false;
				entry.set_size_request(220, -1);
				attach(label, 0, rows);
				attach(entry, 1, rows);
				rows++;
				return entry;
			}

			private FileChooserButton add_filechooser(string text, string title, FileChooserAction action=FileChooserAction.OPEN, bool required=true, out Label label=null)
			{
				label = new Label(text);
				label.halign = Align.START;
				label.xalign = 1;
				label.margin = 4;
				if(required)
				{
					label.get_style_context().add_class("category-label");
				}
				var button = new FileChooserButton(title, action);
				button.set_size_request(220, -1);
				attach(label, 0, rows);
				attach(button, 1, rows);
				rows++;
				return button;
			}

			private void add_separator()
			{
				var separator = new Separator(Orientation.HORIZONTAL);
				separator.margin_top = separator.margin_bottom = 4;
				attach(separator, 0, rows, 2, 1);
				rows++;
			}

			private Box add_switch(string text, bool enabled, owned SettingsDialogTab.SwitchAction action)
			{
				var sw = new Switch();
				sw.active = enabled;
				sw.halign = Align.END;
				sw.notify["active"].connect(() => { action(sw.active); });

				var label = new Label(text);
				label.halign = Align.START;
				label.hexpand = true;

				var hbox = new Box(Orientation.HORIZONTAL, 12);
				hbox.margin_start = 4;

				hbox.add(label);
				hbox.add(sw);

				hbox.show_all();

				attach(hbox, 0, rows, 2, 1);
				rows++;
				return hbox;
			}
		}
	}
}
