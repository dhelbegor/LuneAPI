-- Example demonstrating decoupled template usage in LuneAPI
local LuneAPI = require('luneapi.core')
local Template = require('luneapi.template')

-- Create a new app instance
local app = LuneAPI.new()

-- Create a shared template instance for all routes
local template = Template.new()
template:set_template_dir("LuneAPI/examples/templates")

-- 1. Example route without templates (raw text response)
app:get('/text', function(req, res)
    return res:header('Content-Type', 'text/plain'):send('Hello, World! This is a raw text response.')
end)

-- 2. Example route without templates (JSON response)
app:get('/json', function(req, res)
    local data = {
        message = "Hello, World!",
        time = os.date(),
        version = "1.0.0",
        features = {"Decoupled templates", "JSON responses", "Middleware support"}
    }
    
    return res:header('Content-Type', 'application/json'):send(require('luneapi.jsonify').stringify(data))
end)

-- 3. Example route with template_name parameter (method 1)
app:get('/template1', function(req, res)
    -- Render with context and template_name
    local html = template:render({
        title = "Template Example 1",
        message = "This template was rendered using the template_name parameter",
        time = os.date(),
        items = {"Item 1", "Item 2", "Item 3"}
    }, "example.html")
    
    return res:header('Content-Type', 'text/html'):send(html)
end)

-- 4. Example route with static helper method (method 2)
app:get('/template2', function(req, res)
    -- Directly use the static render_template method with a single path
    local html = Template.render_template(
        "LuneAPI/examples/templates/example.html",
        {
            title = "Template Example 2",
            message = "This template was rendered using the simplified render_template method",
            time = os.date(),
            items = {"Apple", "Banana", "Cherry", "Date"}
        }
    )
    
    return res:header('Content-Type', 'text/html'):send(html)
end)

-- 5. Example route with explicit template rendering (method 3 - string template)
app:get('/template3', function(req, res)
    -- Create a string template
    local template_string = [[
<!DOCTYPE html>
<html>
<head>
    <title>{{ title }}</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; line-height: 1.6; }
        h1 { color: #333; }
        .message { padding: 20px; background-color: #f8f9fa; border-left: 5px solid #007bff; }
        .time { color: #6c757d; font-size: 0.9em; margin-top: 20px; }
    </style>
</head>
<body>
    <h1>{{ title }}</h1>
    <div class="message">{{ message }}</div>
    <div class="time">Current time: {{ time }}</div>
</body>
</html>
    ]]
    
    -- Render the string template
    local html = Template.render_string(
        template_string,
        {
            title = "Template Example 3",
            message = "This template was rendered from a string template",
            time = os.date()
        }
    )
    
    return res:header('Content-Type', 'text/html'):send(html)
end)

-- Create a home page with links to all examples
app:get('/', function(req, res)
    local html = template:render({
        title = "LuneAPI Decoupled Template Example",
        description = "This example demonstrates how the template engine is now completely decoupled from the core framework.",
        examples = {
            {
                title = "Raw Text Response",
                description = "Simple route that returns plain text without using templates.",
                url = "/text"
            },
            {
                title = "JSON Response",
                description = "Route that returns JSON data without using templates.",
                url = "/json"
            },
            {
                title = "Template Rendering (Method 1)",
                description = "Uses the template_name parameter with a shared Template instance.",
                url = "/template1"
            },
            {
                title = "Template Rendering (Method 2)",
                description = "Uses the simplified render_template method with a single path.",
                url = "/template2"
            },
            {
                title = "Template Rendering (Method 3)",
                description = "Renders a template directly from a string.",
                url = "/template3"
            }
        }
    }, "index.html")
    
    return res:header('Content-Type', 'text/html'):send(html)
end)

-- Make sure we have the template files for the example
local function ensure_example_templates()
    local template_dir = "LuneAPI/examples/templates"
    local templates = {
        ["example.html"] = [[
<!DOCTYPE html>
<html>
<head>
    <title>{{ title }}</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; line-height: 1.6; }
        h1 { color: #333; }
        .message { padding: 20px; background-color: #f8f9fa; border-left: 5px solid #007bff; }
        .time { color: #6c757d; font-size: 0.9em; margin-top: 20px; }
        ul { margin-top: 20px; }
        li { margin-bottom: 5px; }
    </style>
</head>
<body>
    <h1>{{ title }}</h1>
    <div class="message">{{ message }}</div>
    
    {% if items and items|length > 0 %}
    <h3>Items:</h3>
    <ul>
        {% for item in items %}
        <li>{{ item }}</li>
        {% endfor %}
    </ul>
    {% endif %}
    
    <div class="time">Current time: {{ time }}</div>
    <p><a href="/">Back to Examples</a></p>
</body>
</html>
        ]],
        ["index.html"] = [[
<!DOCTYPE html>
<html>
<head>
    <title>{{ title }}</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 40px;
            max-width: 800px;
            line-height: 1.6;
        }
        h1 { color: #333; }
        a { color: #007bff; text-decoration: none; }
        a:hover { text-decoration: underline; }
        .examples {
            display: flex;
            flex-direction: column;
            gap: 10px;
            margin-top: 20px;
        }
        .example {
            padding: 15px;
            border: 1px solid #dee2e6;
            border-radius: 4px;
        }
        h3 { margin-top: 0; }
        .description { margin-bottom: 10px; }
    </style>
</head>
<body>
    <h1>{{ title }}</h1>
    <p>{{ description }}</p>
    
    <div class="examples">
        {% for example in examples %}
        <div class="example">
            <h3>{{ example.title }}</h3>
            <div class="description">{{ example.description }}</div>
            <a href="{{ example.url }}">View Example</a>
        </div>
        {% endfor %}
    </div>
</body>
</html>
        ]]
    }
    
    -- Create directory if it doesn't exist
    local lfs_available, lfs = pcall(require, "lfs")
    if lfs_available then
        -- Check if directory exists
        local attr = lfs.attributes(template_dir)
        if not attr or attr.mode ~= "directory" then
            print("Creating template directory: " .. template_dir)
            lfs.mkdir(template_dir)
        end
    end
    
    -- Create each template file
    for filename, content in pairs(templates) do
        local file_path = template_dir .. "/" .. filename
        local file = io.open(file_path, "w")
        if file then
            file:write(content)
            file:close()
            print("Created template: " .. file_path)
        else
            print("Warning: Failed to create template: " .. file_path)
        end
    end
end

-- Ensure we have the template files
ensure_example_templates()

-- Start the server
app:listen(8080, function()
    print("Decoupled Template Example is running at http://localhost:8080")
    print("Available routes:")
    print("  /          - Home page with links to all examples")
    print("  /text      - Plain text response without templates")
    print("  /json      - JSON response without templates")
    print("  /template1 - HTML using template_name parameter")
    print("  /template2 - HTML using simplified render_template method")
    print("  /template3 - HTML using string template rendering")
end) 