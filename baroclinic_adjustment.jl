### Setup dependencies
using Pkg; Pkg.instantiate()

using Oceananigans
using Oceananigans.Units
using Printf

###########-------- SIMULATION PARAMETERS ----------------#############
Lx = 1000kilometers # east-west extent [m]
Ly = 1000kilometers # north-south extent [m]
Lz = 1kilometers    # depth [m]

N² = 1e-5 # [s⁻²] buoyancy frequency / stratification
M² = 1e-7 # [s⁻²] horizontal buoyancy gradient

Δy = 100kilometers # width of the region of the front
Δb = Δy * M²       # buoyancy jump associated with the front
ϵb = 1e-2 * Δb     # noise amplitude


###########-------- GRID SET UP ----------------#############
grid = RectilinearGrid(GPU(),
                       size = (50, 50, 10),
                       x = (0, Lx),
                       y = (-Ly/2, Ly/2),
                       z = (-Lz, 0),
                       topology = (Periodic, Bounded, Bounded))

model = HydrostaticFreeSurfaceModel(; grid,
                                    coriolis = BetaPlane(latitude = 45),
                                    buoyancy = BuoyancyTracer(),
                                    tracers = :b,
                                    momentum_advection = WENO(),
                                    tracer_advection = WENO())


###########-------- STARTING UP MODEL/ICs ---------------#############
"""
    ramp(y, Δy)
Linear ramp from 0 to 1 between -Δy/2 and +Δy/2.
For example:
```
            y < -Δy/2 => ramp = 0
    -Δy/2 < y < -Δy/2 => ramp = y / Δy
            y >  Δy/2 => ramp = 1
```
"""
ramp(y, Δy) = max(min(1, -y/Δy + 1/2), 0)

bᵢ(x, y, z) = N² * z + Δb * ramp(y, Δy) + ϵb * randn()
set!(model, b=bᵢ)


###########-------- SIMULATION SET UP ---------------#############
simulation = Simulation(model, Δt=20minutes, stop_time=20days)

wizard = TimeStepWizard(cfl=0.2, max_change=1.1, max_Δt=20minutes)
simulation.callbacks[:wizard] = Callback(wizard, IterationInterval(20))

wall_clock = Ref(time_ns())

function print_progress(sim)
    u, v, w = model.velocities
    progress = 100 * (time(sim) / sim.stop_time)
    elapsed = (time_ns() - wall_clock[]) / 1e9

    @printf("[%05.2f%%] i: %d, t: %s, wall time: %s, max(u): (%6.3e, %6.3e, %6.3e) m/s, next Δt: %s\n",
            progress, iteration(sim), prettytime(sim), prettytime(elapsed),
            maximum(abs, u), maximum(abs, v), maximum(abs, w), prettytime(sim.Δt))

    wall_clock[] = time_ns()

    return nothing
end

simulation.callbacks[:print_progress] = Callback(print_progress, IterationInterval(100))


###########-------- DIAGNOSTICS --------------#############
@info "Adding Diagnostics..."
u, v, w = model.velocities
b = model.tracers.b
ζ = ∂x(v) - ∂y(u)
B = Average(b, dims=1)
U = Average(u, dims=1)
V = Average(v, dims=1)

filename = "baroclinic_adjustment"
save_fields_interval = 0.5day

slicers = (east = (grid.Nx, :, :),
           north = (:, grid.Ny, :),
           bottom = (:, :, 1),
           top = (:, :, grid.Nz))

for side in keys(slicers)
    indices = slicers[side]

    simulation.output_writers[side] = JLD2OutputWriter(model, (; b, ζ);
                                                       filename = filename * "_$(side)_slice",
                                                       schedule = TimeInterval(save_fields_interval),
                                                       overwrite_existing = true,
                                                       indices)
end

simulation.output_writers[:zonal] = JLD2OutputWriter(model, (; b=B, u=U, v=V);
                                                     filename = filename * "_zonal_average",
                                                     schedule = TimeInterval(save_fields_interval),
                                                     overwrite_existing = true)


###########-------- RUN! --------------#############
@info "Run...."
run!(simulation)
@info "Simulation completed in " * prettytime(simulation.run_wall_time)