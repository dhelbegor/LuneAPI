# LuneAPI Template Engine

The LuneAPI Template Engine is now completely decoupled from the core framework, making it optional for developers to use. This document explains how to use the template engine with your LuneAPI applications.

## Overview

The template engine in LuneAPI is inspired by Jinja2 and provides a powerful way to render dynamic HTML templates. With the decoupling, you can now:

- Use LuneAPI without any template engine dependencies
- Explicitly include the template engine only when needed
- Use alternative template engines if preferred

## Getting Started

### Including the Template Engine

To use the template engine, you need to explicitly require the `template` module:

```lua
local Template = require('luneapi.template')
```

### Basic Usage

There are several ways to use the template engine:

#### 1. Creating a Template Instance with template_name

The recommended approach is to create a template engine instance, set the template directory, and then specify the template name during rendering:

```lua
-- Create a template engine instance
local template = Template.new()

-- Set the template directory
template:set_template_dir("path/to/templates")

-- Render with context and template name
local html = template:render({
    title = "My Page",
    message = "Hello, World!",
    items = {"Item 1", "Item 2", "Item 3"}
}, "page.html")  -- Will load and render path/to/templates/page.html
```

This approach is more flexible and allows you to:
- Reuse the same template engine across multiple templates
- Centralize template directory configuration
- Easily switch between different templates

#### 2. Using Static Helper Methods

For one-off template rendering, you can use the static helper methods:

```lua
-- Render a template directly by file path
local html = Template.render_template(
    "path/to/templates/page.html",
    { title = "My Page", message = "Hello, World!" }
)

-- Render from a string template
local html = Template.render_string(
    "Hello, {{ name }}!",
    { name = "User" }
)
```

## Template Syntax

The template engine supports a variety of syntax features:

### Variable Substitution

```
{{ variable }}
```

### Conditionals

```
{% if condition %}
    Content when condition is true
{% else %}
    Content when condition is false
{% endif %}
```

### Loops

```
{% for item in items %}
    <li>{{ item }}</li>
{% endfor %}
```

### Includes

```
{% include "header.html" %}
```

### Filters

```
{{ string|upper }}
{{ list|length }}
{{ number|format("%.2f") }}
```

## API Reference

### Template.new([template_path])

Creates a new template instance.

- `template_path` (optional): Path to the template file to load

### Instance Methods

#### template:load_template(file_path)

Loads a template from the given file path.

#### template:set_template_string(template_string)

Sets the template content from a string.

#### template:compile()

Compiles the loaded template.

#### template:render(context, [template_name])

Renders the template with the provided context.

- `context`: Table containing values to use in the template
- `template_name` (optional): Name of the template file to load from the template directory

#### template:set_template_dir(dir)

Sets the template directory for includes and other template features.

#### template:set_error_handler(handler)

Sets a custom error handler function.

### Static Methods

#### Template.render_file(file_path, context)

Renders a template file with the given context.

#### Template.render_string(template_string, context)

Renders a template string with the given context.

#### Template.render_template(file_path, context)

Renders a template by its full file path with the given context. The directory part of the path is automatically extracted and used for template includes.

## Examples

See the `decoupled_template_example.lua` file in the examples directory for a complete example of using the template engine with LuneAPI.

## Migrating Existing Code

If you're migrating from a previous version of LuneAPI that had the template engine built-in, you'll need to update your code to explicitly include the template engine. Here's how to update common patterns:

### Before

```lua
local LuneAPI = require('luneapi.core')
local app = LuneAPI.new()

-- The template engine was automatically available
app:set_template_dir("./templates")

app:get('/', function(req, res)
    return res:render("index.html", { title = "Home" })
end)
```

### After

```lua
local LuneAPI = require('luneapi.core')
local Template = require('luneapi.template')
local app = LuneAPI.new()

-- Create a central template for the application
local template = Template.new()
template:set_template_dir("./templates")

app:get('/', function(req, res)
    local html = template:render({ title = "Home" }, "index.html")
    return res:header('Content-Type', 'text/html'):send(html)
end)
```

## Best Practices

1. **Central Template Instance**: Create a single template instance and reuse it across routes.

2. **Set Template Directory Once**: Set the template directory once at application startup.

3. **Use template_name Parameter**: Use the `template_name` parameter with `render()` rather than loading templates directly.

4. **Error Handling**: Consider setting a custom error handler for better debugging experience.

5. **Template Organization**: Organize your templates in a logical directory structure and reference them with relative paths in the `template_name` parameter. 