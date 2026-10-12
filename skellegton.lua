local EyesMaterial = nil
local EyesFileName = "eyes_twemoji.png"
local EyesMaterialPath = "../data/" .. EyesFileName

if file.Exists(EyesFileName, "DATA") then
    EyesMaterial = Material(EyesMaterialPath, "smooth")
else
    local url = "https://github.com/jdecked/twemoji/blob/main/assets/72x72/1f440.png?raw=true"
    http.Fetch(url, function(body, _, _, statusCode)
        if statusCode ~= 200 then
            print("HTTP " .. statusCode)
            return
        end

        if not file.Write(EyesFileName, body) then
            print("Eyes twemoji fetch; failed to write image.")
            return
        end

        EyesMaterial = Material(EyesMaterialPath, "smooth")
    end, function(err)
        print("Failed to fetch eyes twemoji: "..err)
    end)
end


local DrawEye
do
    local eye_mesh = Mesh()
    mesh.Begin(eye_mesh,MATERIAL_QUADS,1)
        mesh.Position(0,0,0)
        mesh.Color(255,255,255,255)
        mesh.TexCoord(0,0,0)
        mesh.AdvanceVertex()

        mesh.Position(1,0,0)
        mesh.Color(255,255,255,255)
        mesh.TexCoord(0,0.5,0)
        mesh.AdvanceVertex()

        mesh.Position(1,1,0)
        mesh.Color(255,255,255,255)
        mesh.TexCoord(0,0.5,1)
        mesh.AdvanceVertex()

        mesh.Position(0,1,0)
        mesh.Color(255,255,255,255)
        mesh.TexCoord(0,0,1)
        mesh.AdvanceVertex()
    mesh.End()
    local draw_matrix = Matrix()
    function DrawEye(x,y,w,h)
        if not EyesMaterial then return end
        render.SetMaterial(EyesMaterial)

        draw_matrix:SetUnpacked(
            w,0,0,x,
            0,h,0,y,
            0,0,1,0,
            0,0,0,1
        )
        cam.PushModelMatrix(draw_matrix)
            eye_mesh:Draw()
        cam.PopModelMatrix()
    end
end

local Skeletons = {}

local function PushSkeleton(time)
    local skeleton_data = {}
    local skelly_model = ClientsideModel("models/player/skeleton.mdl")
    if not skelly_model then return end

    skelly_model:SetSkin(1)
    skelly_model:SetNoDraw(true)
    skelly_model:SetSequence("run_all_01")
    skelly_model:SetPoseParameter("move_x",400)

    skeleton_data.Model = skelly_model
    skeleton_data.CreationTime = CurTime()
    skeleton_data.LifeTime = time or 1

    table.insert(Skeletons,1,skeleton_data)
end

local eyes_intensity = 0
local eyes_off_delay = 2
local eyes_off_start = 0
local eyes_appearing = false

hook.Add("Think","SkellyPass",function()

    for i = #Skeletons,1,-1 do
        local data = Skeletons[i]
        if not data then continue end
        local time = CurTime()-data.CreationTime
        local fraction = (time/data.LifeTime)%1

        local mdl = data.Model

        if fraction>0.8 then
            eyes_appearing = true
        end

        mdl:SetPos(Vector(400*fraction,0,0))
        mdl:SetCycle(fraction*2)

        if time>data.LifeTime then
            table.remove(Skeletons,i)
            continue
        end
    end


    if eyes_appearing then
        eyes_intensity = eyes_intensity + math.min(FrameTime(),1-eyes_intensity)

        eyes_off_start = CurTime()+eyes_off_delay

        if #Skeletons==0 and eyes_intensity==1 then
            eyes_appearing = false
        end
    elseif CurTime()>=eyes_off_start then
        eyes_intensity = eyes_intensity - math.min(FrameTime(),eyes_intensity)
    end
end)


local color_mod = {
    [ "$pp_colour_brightness" ] = 0,
    [ "$pp_colour_contrast" ] = 1,
    [ "$pp_colour_colour" ] = 1,
}

local width = 1.5
hook.Add("HUDPaint", "SkellyPass", function()
    if not EyesMaterial then return end

    if eyes_intensity>0 then
        color_mod["$pp_colour_colour"] = 1-eyes_intensity
        DrawColorModify(color_mod)

        local height_scale = 0
        if eyes_appearing then
            height_scale = math.ease.OutElastic(eyes_intensity)
        else
            height_scale = math.ease.InExpo(eyes_intensity)
        end

        for k,ent in ipairs(ents.GetAll()) do
            if ent:GetNoDraw() then continue end
            if not ent:IsPlayer() and not ent:IsNPC() then continue end
            if not ent:Alive() then continue end
            if ent == LocalPlayer() and not LocalPlayer():ShouldDrawLocalPlayer() then continue end

            for _,att_data in pairs(ent:GetAttachments()) do
                if att_data.name ~= "eyes" then continue end
                local att_pos = ent:GetAttachment(att_data.id)
                local pos = att_pos.Pos

                if att_pos.Ang:Forward():Dot(EyePos()-pos)<0 then continue end

                cam.Start3D()
                local scale = render.ComputePixelDiameterOfSphere(pos,10)
                cam.End3D()

                local left = (pos-att_pos.Ang:Right()*width):ToScreen()
                local right = (pos+att_pos.Ang:Right()*width):ToScreen()

                local trc = util.TraceLine({
                    start = EyePos(),
                    endpos = pos,
                    filter = {LocalPlayer(),ent},
                    mask = MASK_OPAQUE
                })


                if trc.HitPos:Distance(pos)>10 then continue end

                -- draw.DrawText( att_data.name, nil, pos.x, pos.y, nil, TEXT_ALIGN_CENTER )
                local w = 0.1*scale
                local h = 0.2*scale*height_scale
                DrawEye(left.x-w*0.5,left.y-h*0.5,w,h)
                DrawEye(right.x-w*0.5,right.y-h*0.5,w,h)
            end
        end
    end

    cam.Start3D(Vector(300,230,70),Angle(10,255.5,0),72)
    render.SuppressEngineLighting(true)
    for k,data in ipairs(Skeletons) do
        data.Model:DrawModel()
    end
    render.SuppressEngineLighting(false)
    cam.End3D()
end)

net.Receive("skellypass",function()
    PushSkeleton(net.ReadFloat())
end)
