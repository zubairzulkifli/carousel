-- Copyright (c) 2016, Florian Wesch <fw@dividuum.de>
-- All rights reserved.
-- 
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions
-- are met:
-- 
-- 1. Redistributions of source code must retain the above copyright
--    notice, this list of conditions and the following disclaimer.
-- 
-- 2. Redistributions in binary form must reproduce the above copyright
--    notice, this list of conditions and the following disclaimer
--    in the documentation and/or other materials provided with the
--    distribution.
-- 
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
-- "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
-- LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
-- FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
-- COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
-- INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
-- BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
-- LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
-- CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
-- LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
-- ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
-- POSSIBILITY OF SUCH DAMAGE.

--[ Configuration ]--------------------------------------

local DEBUG = false
local COVER_SWITCH_TIME = 1
local FONT = "font.ttf"
local FONT_SIZE = 100
local IMG_SIZE = { w = 500, h = 656 }

---------------------------------------------------------

gl.setup(NATIVE_WIDTH, NATIVE_HEIGHT)

node.alias "c"
node.set_flag "close_clients"

local json = require "json"
local screen = sys.get_ext "screen"

local center_x = WIDTH / 2
local center_y = HEIGHT / 2

local bg = resource.load_image "background.jpg"
local dummy = resource.create_colored_texture(.5, .5, .5, .5)
local white = resource.create_colored_texture(1,1,1,1)
local font = resource.load_font(FONT)

util.noglobals()

local mixer = resource.create_shader[[
    uniform sampler2D Texture;
    uniform sampler2D Thumb;
    uniform vec4 Color;
    uniform float Mix;
    varying vec2 TexCoord;

    void main() {
        vec4 col1 = texture2D(Texture, TexCoord);
        vec4 col2 = texture2D(Thumb, TexCoord);
        vec4 col = mix(col2, col1, Mix);
        col.a = Color.a;
        gl_FragColor = col;
    }
]]

local function lerp(v, t, s)
    return v*s + t*(1-s)
end

local next_load = sys.now()

local function Cover(filename)
    local thumb, full

    local ratio
    local target_ratio = 0

    local function load_thumb()
        if thumb then return end
        thumb = resource.load_image{
            file = ("%s-thumb.jpg"):format(filename),
        }
    end

    local function load_full()
        if full then return end
        if sys.now() < next_load then
            return
        end
        next_load = sys.now() + 0.05
        full = resource.load_image{
            file = ("%s.jpg"):format(filename),
        }
    end

    local function unload()
        print("unloading image", filename)
        if thumb then
            thumb:dispose() 
            thumb = nil
        end
        if full then
            full:dispose()
            full = nil
        end
        ratio = nil
    end

    local function prepare(show_full)
        local image

        if not thumb then
            load_thumb()
        end

        local thumb_loaded = thumb:state() == "loaded"

        if show_full and thumb_loaded then
            load_full()
        end

        local full_loaded = full and full:state() == "loaded" or false

        local unloaded = not thumb_loaded and not full_loaded

        if unloaded then
            return
        end

        if not ratio then
            if show_full and full_loaded then
                target_ratio = 1
                ratio = 1
            elseif thumb_loaded then
                target_ratio = 0
                ratio = 0
            else
                return
            end
        end

        if full then
            target_ratio = 1
        elseif not show_full and thumb then
            target_ratio = 0
        end

        if thumb_loaded and full_loaded then
            ratio = ratio * 0.95 + target_ratio * 0.05
        end
    end

    local function draw(...)
        if not ratio then
            return dummy:draw(...)
        elseif ratio < 0.10 then
            thumb:draw(...)
        elseif ratio > 0.95 then
            full:draw(...)
        else
            mixer:use{
                Thumb = thumb,
                Mix = ratio,
            }
            full:draw(...)
            mixer:deactivate()
        end
    end

    return {
        unload = unload;
        prepare = prepare;
        draw = draw;
    }
end

local function Carousel(opt)
    local width = opt.width
    local height = opt.height
    local margin = opt.margin
    local images = opt.images

    local covers = {}
    local pos = 0

    for i = 1, #images do
        covers[i] = Cover(images[i])
    end

    local function selected_idx()
        local idx = math.floor(pos + 0.5) % #covers + 1
        return images[idx], idx
    end

    local function draw(show_full, alpha)
        local current_idx = math.floor(pos)

        -- prepare covers from inside going to the edges.
        -- that way the inner covers are loaded first.
        for f = 1, margin*2+2 do
            local offset = math.floor(f/2) * math.pow(-1, f)
            local idx = (current_idx + offset) % #covers + 1
            covers[idx].prepare(show_full)
        end

        -- draw from outside to inside for 3D effect.
        for f = margin*2+2, 1, -1 do
            local offset = math.floor(f/2) * math.pow(-1, f)
            local idx = (current_idx + offset) % #covers + 1

            local rel_x = ((current_idx + offset) - pos) * width
            gl.pushMatrix()
                local dist = (1-math.cos(rel_x/500))*600
                local x = (math.cos(rel_x/5000))*rel_x*1.3
                gl.translate(center_x+x, center_y, dist)
                covers[idx].prepare(show_full)
                covers[idx].draw(-width/2, -height/2, width/2, height/2, alpha)
                if DEBUG then
                    font:write(0, 0, current_idx+offset, 100, 1,0,0,alpha)
                    font:write(0, 100, images[idx], 100, 1,0,0,alpha)
                end
            gl.popMatrix()
        end
    end


    local function set_pos(new_pos)
        local current_idx = math.floor(pos)
        local new_idx = math.floor(new_pos)

        local dist = new_idx - current_idx

        if dist > 0 then
            local left_idx = (current_idx - margin) % #covers + 1
            -- print("unloading left ", left_idx)
            covers[left_idx].unload()
        elseif dist < 0 then
            local right_idx = (current_idx + margin+1) % #covers + 1
            -- print("unloading right", right_idx)
            covers[right_idx].unload()
        end

        pos = new_pos
    end

    local function unload_all()
        for i = 1, #images do
            covers[i].unload()
        end
    end

    return {
        draw = draw;
        set_pos = set_pos;
        selected_idx = selected_idx;
        unload_all = unload_all;
    }
end

local function Cursor(opt)
    local target = 0
    local pos = 0
    local speed = 0

    local function update_target(d)
        target = target + d
    end

    local function stop()
        if speed < -0.01 then
            print("rotating left", pos, "to", target)
            target = math.floor(pos+0.1)
            print("new target", target)
        elseif  speed > 0.01 then
            print("rotating right", pos, "to", target)
            target = math.ceil(pos-0.1)
            print("new target", target)
        end
    end

    local function update()
        local delta = target-pos
        local abs_delta = math.abs(delta)
        local abs_speed = math.abs(speed)
        speed = lerp(speed, delta, 0.90 - abs_delta/10)
        -- speed = lerp(speed, delta, math.min(0.90, 1 - 1.0 / (10+abs_delta)))
        -- speed = lerp(speed, delta, math.min(0.90, 0.90 - math.abs(delta)/20))
        -- speed = math.max(-abs_delta, math.min(abs_delta, lerp(speed, delta, 0.90)))
        -- speed = lerp(speed, delta, 0.90)
        pos = lerp(pos, pos + speed, 0.98)
        return speed, pos
    end

    return {
        update_target = update_target;
        stop = stop;
        update = update;
    }
end

local function Navigation()
    local switch_time = COVER_SWITCH_TIME

    local visible = -30
    local target_visible = 1

    local carousel = nil
    local cursor = Cursor()

    local title = ""
    local next_switch = nil
    local next_config_raw = nil
    local next_direction = nil

    local function ease(t)
        return -0.5 * (math.cos(math.pi * t) - 1.0)
    end

    local function update(direction, config_raw)
        if direction == "up" then
            next_direction = -1
        else
            next_direction = 1
        end
        next_config_raw = config_raw
        next_switch = sys.now() + switch_time / 2
    end

    local function update_target(delta)
        if not cursor then return end
        cursor.update_target(delta)
    end

    local function stop()
        if not cursor then return end
        cursor.stop()
    end

    local function get_current_image()
        if not carousel then return end
        return carousel.selected_idx()
    end

    local function fadeout()
        target_visible = 0
    end

    local function fadein()
        target_visible = 1
    end

    local function draw()
        local y = 0
        local now = sys.now()
        local delta

        if next_switch then
            local dt = math.abs(next_switch - now)
            -- print(dt)
            if dt < switch_time / 2 then
                local invert = 1
                if now > next_switch then
                    invert = -1
                end
                y = ease(1 - dt/switch_time * 2) * 1400 * next_direction * invert
            end
            -- print(y)

            if now > next_switch and next_config_raw then
                local config = json.decode(next_config_raw)
                local images = config.images
                -- Duplicate images list until we have at least 10 images.
                -- This is required to prevent showing the same Cover object
                -- on a single screen.
                while #images < 10 do
                    for i = 1, #images do
                        images[#images+1] = images[i]
                    end
                end

                if carousel then
                    carousel.unload_all()
                end

                carousel = Carousel{
                    width = IMG_SIZE.w,
                    height = IMG_SIZE.h,
                    margin = 2;
                    images = images;
                }
                title = config.title
                next_config_raw = nil
            end
        end

        visible = lerp(visible, target_visible, 0.90)
        if math.abs(visible - target_visible) < 0.05 then
            visible = lerp(visible, target_visible, 0.8)
        end

        if visible < 0.01 then
            screen.set_swap_interval(3)
        else
            screen.set_swap_interval(1)
        end

        local border = (1-visible)*200
        bg:draw(0-border*1.6, 0-border, WIDTH+border*1.6, HEIGHT+border, visible)

        if not carousel then return end
        assert(cursor)

        local title_width = font:width(title, FONT_SIZE)
        font:write(center_x - title_width/2, 80 + y, title, FONT_SIZE, 1,1,1,0.9*visible)

        local dist = (1-visible)*900
        local zoom = (1-visible)*10
        local fov = math.atan2(HEIGHT, WIDTH*2) * 360 / math.pi
        gl.perspective(fov+zoom, center_x, -100+center_y+y/2, -WIDTH + math.abs(y)/2 + dist,
                            center_x, -100+center_y-y,   0 + dist)

        local speed, pos = cursor.update()
        carousel.set_pos(pos)
        carousel.draw(math.abs(speed) < 0.3, visible)
    end


    return {
        update = update;
        draw = draw;

        stop = stop;
        update_target = update_target;
        fadein = fadein;
        fadeout = fadeout;

        get_current_image = get_current_image;
    }
end

local nav = Navigation()

local function Clients()
    local clients = {}

    local function prompt(read, write)
        while true do
            local cmd = read()
            if cmd == "u" then
                nav.update("up", read())
            elseif cmd == "d" then
                nav.update("down", read())
            elseif cmd == "l" then
                nav.update_target(-1)
            elseif cmd == "s" then
                nav.stop()
            elseif cmd == "r" then
                nav.update_target(1)
            elseif cmd == "p" then
                local image = nav.get_current_image()
                write(image)
            elseif cmd == "o" then
                nav.fadeout()
            elseif cmd == "i" then
                nav.fadein()
            else
                write("huh?")
            end
        end
    end

    node.event("connect", function(client)
        local handler = coroutine.wrap(prompt)
        clients[client] = handler
        handler(function()
            return coroutine.yield()
        end, function(...)
            node.client_write(client, ...)
        end)
    end)

    node.event("input", function(line, client)
        clients[client](line)
    end)

    node.event("disconnect", function(client)
        clients[client] = nil
    end)

    local function write_all(...)
        for client, _ in pairs(clients) do
            node.client_write(client, ...)
        end
    end

    return {
        write_all = write_all;
    }
end

local clients = Clients()

nav.update("up", [[
    {
        "title": "init",
        "images": ["0001", "0002", "0003", "0004", "0005"]
    }
]])

function node.render()
    return nav.draw()
end
