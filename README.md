# Friendly Potato CMS
A string-only CMS written with Godot 3.3.

A key-value store for managing text and their translations that can be exported to JSON for use in your application.

### JSON export layout
```
{
  "en": {
    "hello_world": "This is the value for hello_world"
  },
  "other lang": {
    ..
  }
}
```

### Note
Developed for use on Windows. Other platforms will probably work but support for non-Western font faces might be lacking. Even on Windows, only Western font faces like Latin and Cyrillic and Asian characters like Simplified Chinese and Japanese are supported.

## Quickstart
The app assumes you have a main table called 'cms' (one is auto-generated for you). Write raw SQL queries to insert data or use one of the query helpers (SELECT, INSERT, UPDATE, DELETE) to modify data. Export your data to json using one of the bottom buttons.

All data is stored in the application directory.

## Shortcuts
Control + UP (while in raw query): Get the last query executed

Control + DOWN (while in raw query): Get the next query executed

