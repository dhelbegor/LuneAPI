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
    -- Start rendering timer
    local start_time = os.clock()
    
    -- Get cache stats before rendering
    local cache_stats = { hits = 0, misses = 0, size = 0, max_size = 0 }
    if app.template.get_cache_stats then
        cache_stats = app.template.get_cache_stats() or cache_stats
    end
    
    -- Calculate hit ratio with defaults to avoid division by zero
    local cache_hit_ratio = 0
    if (cache_stats.hits + cache_stats.misses) > 0 then
        cache_hit_ratio = math.floor((cache_stats.hits / (cache_stats.hits + cache_stats.misses)) * 100)
    end
    
    -- Create context with all demo data
    local context = {
        title = "Template Documentation",
        page_title = "Template Engine Documentation",
        content_template = "docs/template_doc.html",
        current_year = os.date("%Y"),
        
        -- Basic demo data
        name = "John Doe",
        is_admin = true,
        is_minor = false,
        age = 25,
        items = {"Apple", "Banana", "Cherry", "Date"},
        empty_list = {},
        sample_text = "This is a sample text for demonstration purposes.",
        long_text = "This is a very long text that will be truncated.",
        number = 1234567.89,
        date = os.time(),
        
        -- User object demo
        user = {
            name = "Jane Smith",
            email = "jane@example.com",
            admin = true
        },
        
        -- Template inclusion variables
        template_var = "docs/include_demo",
        
        -- Cache statistics
        cache_stats = cache_stats,
        cache_hit_ratio = cache_hit_ratio,
        
        -- Will be filled in after rendering
        render_time = 0
    }
    
    -- Render the template
    local html = app.template.render_file("LuneAPI/examples/templates/base.html", context)
    
    -- Calculate rendering time
    local render_time = math.floor((os.clock() - start_time) * 1000)
    
    -- Add rendering time to the HTML
    html = html:gsub("{{ render_time }}", tostring(render_time))
    
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