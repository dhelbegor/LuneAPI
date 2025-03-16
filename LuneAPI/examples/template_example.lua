-- Example application using LuneAPI Template Engine

local LuneAPI = require('luneapi.core')

-- Create a new app instance
local app = LuneAPI.new()

-- Set the template directory
app:set_template_dir("LuneAPI/examples/templates")

-- Dummy user data for demonstration
local users = {
    {
        name = "John Doe",
        email = "john@example.com",
        admin = true,
        joined = os.time() - 86400 * 30, -- 30 days ago
        bio = "John is a software developer with over 10 years of experience. He specializes in web development and enjoys building robust applications."
    },
    {
        name = "Jane Smith",
        email = "jane@example.com",
        admin = false,
        joined = os.time() - 86400 * 15, -- 15 days ago
        bio = "Jane is a UI/UX designer who loves creating beautiful and intuitive user interfaces. She has worked on numerous projects across different industries."
    },
    {
        name = "Bob Johnson",
        email = "bob@example.com",
        admin = true,
        joined = os.time() - 86400 * 5, -- 5 days ago
        bio = "Bob is a recent computer science graduate excited to start his career in technology. He's passionate about learning new programming languages and frameworks."
    }
}

-- Home route
app:get('/', function(req, res)
    local html = app.template.render_file("LuneAPI/examples/templates/base.html", {
        page_title = "Welcome to LuneAPI",
        message = "This is a demonstration of the LuneAPI template engine.",
        content_template = "welcome.html",
        current_year = os.date("%Y")
    })
    
    return res:header('Content-Type', 'text/html'):send(html)
end)

-- Users route
app:get('/users', function(req, res)
    local html = app.template.render_file("LuneAPI/examples/templates/base.html", {
        title = "User List",
        page_title = "User Directory", 
        users = users,
        content_template = "users.html",
        current_year = os.date("%Y")
    })
    
    return res:header('Content-Type', 'text/html'):send(html)
end)

-- User detail route
app:get('/user/:id', function(req, res)
    local id = tonumber(req.params.id)
    local user = id and id <= #users and users[id] or nil
    
    if not user then
        return res:status(404):send("User not found")
    end
    
    local context = {
        title = "User Profile: " .. user.name,
        page_title = "User Profile",
        user = user,
        current_year = os.date("%Y")
    }
    
    -- Simple template string for demonstration
    local template_str = [[
        <div class="card">
            <h2>{{ user.name|upper }}</h2>
            <p><strong>Email:</strong> {{ user.email }}</p>
            <p><strong>Role:</strong> {% if user.admin %}Administrator{% else %}Regular User{% endif %}</p>
            <p><strong>Joined:</strong> {{ user.joined|date_format("%B %d, %Y") }}</p>
            <h3>Biography</h3>
            <p>{{ user.bio }}</p>
            <a href="/users" class="btn">Back to Users</a>
        </div>
    ]]
    
    -- Direct rendering of template string
    context.content_template = "user_detail.html"
    
    -- Create user_detail.html dynamically
    local file = io.open("LuneAPI/examples/templates/user_detail.html", "w")
    if file then
        file:write(template_str)
        file:close()
    end
    
    local html = app.template.render_file("LuneAPI/examples/templates/base.html", context)
    return res:header('Content-Type', 'text/html'):send(html)
end)

-- Template syntax demonstration
app:get('/template-demo', function(req, res)
    local template_str = [[
    <h2>Template Engine Demo</h2>
    
    <div class="card">
        <h3>Variable Substitution</h3>
        <p>Simple variable: {{ name }}</p>
        <p>Filtered variable: {{ name|upper }}</p>
        <p>Default value: {{ age|default("Not specified") }}</p>
    </div>
    
    <div class="card">
        <h3>Conditionals</h3>
        {% if is_admin %}
            <p>Welcome, administrator!</p>
        {% else %}
            <p>Welcome, user!</p>
        {% endif %}
        
        {% if age and age >= 18 %}
            <p>You are an adult.</p>
        {% elseif age %}
            <p>You are under 18.</p>
        {% else %}
            <p>Age not provided.</p>
        {% endif %}
    </div>
    
    <div class="card">
        <h3>Loops</h3>
        <ul>
        {% for item in items %}
            <li>
                {{ loop.index }}. {{ item }}
                {% if loop.first %} (first item){% endif %}
                {% if loop.last %} (last item){% endif %}
            </li>
        {% endfor %}
        </ul>
    </div>
    
    <div class="card">
        <h3>Filters</h3>
        <p>Original: {{ sample_text }}</p>
        <p>Uppercase: {{ sample_text|upper }}</p>
        <p>Lowercase: {{ sample_text|lower }}</p>
        <p>Truncated: {{ sample_text|truncate(20) }}</p>
        <p>Number format: {{ number|number_format(2) }}</p>
        <p>Date format: {{ date|date_format("%Y-%m-%d %H:%M") }}</p>
    </div>
    
    <a href="/" class="btn">Back to Home</a>
    ]]
    
    local context = {
        title = "Template Demo",
        page_title = "Template Syntax Demo",
        content_template = "demo.html",
        current_year = os.date("%Y"),
        
        -- Demo data
        name = "John Doe",
        is_admin = true,
        age = 25,
        items = {"Apple", "Banana", "Cherry", "Date"},
        sample_text = "This is a sample text for demonstration purposes.",
        number = 1234567.89,
        date = os.time()
    }
    
    -- Create demo.html dynamically
    local file = io.open("LuneAPI/examples/templates/demo.html", "w")
    if file then
        file:write(template_str)
        file:close()
    end
    
    local html = app.template.render_file("LuneAPI/examples/templates/base.html", context)
    return res:header('Content-Type', 'text/html'):send(html)
end)

-- Create a welcome template
local welcome_tmpl = [[
<h2>Welcome to LuneAPI Template Engine</h2>

<div class="card">
    <h3>Features</h3>
    <ul>
        <li>Variable substitution with <pre style="display:inline;">{{ variable }}</pre></li>
        <li>Conditionals with <pre style="display:inline;">{% if condition %} {% endif %}</pre></li>
        <li>Loops with <pre style="display:inline;">{% for item in items %} {% endfor %}</pre></li>
        <li>Includes with <pre style="display:inline;">{% include template %}</pre></li>
        <li>Filters with <pre style="display:inline;">{{ variable|filter }}</pre></li>
        <li>Comments with <pre style="display:inline;">{# This is a comment #}</pre></li>
    </ul>
</div>

<div class="card">
    <h3>Examples</h3>
    <ul>
        <li><a href="/users">User List</a> - Shows data rendering with loops and conditionals</li>
        <li><a href="/user/1">User Profile</a> - Shows dynamic template generation</li>
        <li><a href="/template-demo">Template Syntax</a> - Demonstrates all template features</li>
    </ul>
</div>
]]

-- Create welcome.html
local file = io.open("LuneAPI/examples/templates/welcome.html", "w")
if file then
    file:write(welcome_tmpl)
    file:close()
end

-- Start the server
app:listen(8080, function()
    print("Template example server is running at http://localhost:8080")
    print("Visit the following routes to see the template engine in action:")
    print("  - / (Home)")
    print("  - /users (User List)")
    print("  - /user/1 (User Profile)")
    print("  - /template-demo (Template Syntax Demo)")
end) 