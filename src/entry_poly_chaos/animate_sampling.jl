
function animate_traj(t_sim, samples)
vis = Visualizer()
open(vis)
delete!(vis)
#Plot Mars in MeshCat
image = PngImage(joinpath(MeshCat.VIEWER_ROOT, "..", "data", "8k_mars.png"))
texture = Texture(image=image)
material = MeshLambertMaterial(map=texture)
planet = HyperSphere(Point(0.,0,0), 5.0)
geometry = planet
setobject!(vis["planet"], geometry, material)
settransform!(vis["planet"], LinearMap(AngleAxis(pi/2, 1, 0, 0))) #rotate Planet

#Plot Spacecraft
image = PngImage(joinpath(MeshCat.VIEWER_ROOT, "..", "data", "tex_body.png"))
texture= Texture(image = image)
material = MeshLambertMaterial(map=texture)
cap = load(joinpath(MeshCat.VIEWER_ROOT, "..", "data", "orion_100_smaller.obj"), GLUVMesh)
setobject!(vis["vehicle"], cap, material)
#settransform!(vis["vehicle"], LinearMap(AngleAxis(pi/2, 1.0, 0, 0)))
#settransform!(vis["vehicle"], LinearMap(Quat(Q...)))
    #Material
red_material = MeshPhongMaterial(color=RGBA(1, 0, 0, 1.0))
green_material = MeshPhongMaterial(color=RGBA(0, 1, 0, 1.0))

    #Points Trajectory
sphere_small = HyperSphere(Point(0.0,0.0,0.0), 0.005)

    #Plot Trajectory
traj = vis["traj"]
vehicle = vis["vehicle"]

N = length(t_sim)


    #Building Animation
anim = MeshCat.Animation()
for i = 1:N
    for j =1:300:Ms
    Z = samples[:, :, j]
    MeshCat.atframe(anim,vis,i) do frame
        settransform!(frame["vehicle"], compose(Translation(Z[1:3, i].*5...),LinearMap(Quat(qmult(Z[4:7, i], QQ)...))))
    end
    setobject!(vis["traj"]["t$i"],sphere_small, green_material)
    settransform!(vis["traj"]["t$i"], Translation(Z[1, i]*5, Z[2, i]*5, Z[3, i]*5))
    camera_translation = Translation(-0.5, 1.0, 1.0)
    camera_rotation = LinearMap(AngleAxis(0.6*pi, 0.0, 0.0, 1.0))
    MeshCat.atframe(anim, vis, i) do frame
        #setprop!(frame["/Cameras/default/rotated/<object>"], "zoom", 1.5)
        #settransform!(frame["/Cameras/default"], Translation(5, 0, 0))
        #settransform!(frame["/Cameras/default"], compose(compose(compose(Translation(Z[1:3, i].*10...), LinearMap(Quat(qmult(Z[4:7, i], QQ)...))), camera_translation), camera_rotation))
    end
end
end

MeshCat.setanimation!(vis,anim)
#settransform!(vis["/Cameras/default"], Translation(5, 0, 0))

end
