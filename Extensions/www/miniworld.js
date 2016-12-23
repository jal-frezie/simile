SYSTO.modelSpecs.miniworld = {
    "meta": {
        "id": "miniworld",
        "name": "Miniworld",
        "title": "Simple model of global population dynamics, production and pollution",
        "author": "Robert Muetzelfeldt; original model by Hartmut Bossel",
        "description": "The model represents the world in terms of three state variables (stocks): population, environmental pollution, and production capacity (all standardized to an initial value of 1).  The global human population increases by births and is reduced by deaths. The number of births per year depends on the size of the population, the birth rate, and a birth control parameter. It is also affected by the consumption level and by the quality of environment.   Environmental pollution arises from the interplay of environmental degradation and regeneration. The amount of degradation depends on population, its consumption level and the specific degradation rate. Regeneration is determined by a damage threshold, the quality of environment and current environmental pollution.   Production capacity increases at a rate which depends on consumption level and environmental pollution.To see a Systo page dedicated to this model, please go to http://www.systo.org/miniworld.html",
        "language": "system_dynamics"
    },
    "nodes": [
        {
            "id": "cloud1",
            "type": "cloud",
            "centrex": 37,
            "centrey": 239
        },
        {
            "id": "cloud2",
            "type": "cloud",
            "centrex": 352,
            "centrey": 243
        },
        {
            "id": "cloud3",
            "type": "cloud",
            "centrex": 265,
            "centrey": 113
        },
        {
            "id": "cloud4",
            "type": "cloud",
            "centrex": 628,
            "centrey": 117
        },
        {
            "id": "cloud5",
            "type": "cloud",
            "centrex": 614,
            "centrey": 341
        },
        {
            "id": "stock1",
            "type": "stock",
            "label": "Population",
            "centrex": 215,
            "centrey": 241,
            "equation": "1"
        },
        {
            "id": "stock3",
            "type": "stock",
            "label": "Environ_pollution",
            "centrex": 434,
            "centrey": 117,
            "equation": "1"
        },
        {
            "id": "stock5",
            "type": "stock",
            "label": "Production_capacity",
            "centrex": 415,
            "centrey": 342,
            "equation": "1"
        },
        {
            "id": "valve1",
            "type": "valve",
            "label": "births",
            "equation": "birth_rate*Population*quality_of_environment*consumption_level*birth_control"
        },
        {
            "id": "valve2",
            "type": "valve",
            "label": "deaths",
            "equation": "death_rate*Population*Environ_pollution"
        },
        {
            "id": "valve3",
            "type": "valve",
            "label": "degradation",
            "equation": "degradation_rate*Population*consumption_level"
        },
        {
            "id": "valve4",
            "type": "valve",
            "label": "regeneration",
            "equation": "quality_of_environment>1?regeneration_rate*Environ_pollution:regeneration_rate*damage_threshold"
        },
        {
            "id": "valve5",
            "type": "valve",
            "label": "capacity_increase",
            "equation": "growth_rate*consumption_level*Environ_pollution*(1-(consumption_level*Environ_pollution/consumption_goal))"
        },
        {
            "id": "variable1",
            "type": "variable",
            "label": "birth_rate",
            "centrex": 140,
            "centrey": 321,
            "equation": "0.03+rand_var(0,0.1)"
        },
        {
            "id": "variable11",
            "type": "variable",
            "label": "regeneration_rate",
            "centrex": 643,
            "centrey": 170,
            "equation": "0.1"
        },
        {
            "id": "variable13",
            "type": "variable",
            "label": "degradation_rate",
            "centrex": 641,
            "centrey": 207,
            "equation": "0.02"
        },
        {
            "id": "variable15",
            "type": "variable",
            "label": "consumption_goal",
            "centrex": 630,
            "centrey": 250,
            "equation": "10"
        },
        {
            "id": "variable17",
            "type": "variable",
            "label": "growth_rate",
            "centrex": 634,
            "centrey": 291,
            "equation": "0.05"
        },
        {
            "id": "variable19",
            "type": "variable",
            "label": "consumption_level",
            "centrex": 469,
            "centrey": 233,
            "equation": "Production_capacity"
        },
        {
            "id": "variable3",
            "type": "variable",
            "label": "birth_control",
            "centrex": 72,
            "centrey": 348,
            "equation": "1"
        },
        {
            "id": "variable5",
            "type": "variable",
            "label": "death_rate",
            "centrex": 257,
            "centrey": 318,
            "equation": "0.01"
        },
        {
            "id": "variable7",
            "type": "variable",
            "label": "quality_of_environment",
            "centrex": 318,
            "centrey": 50,
            "equation": "damage_threshold/Environ_pollution"
        },
        {
            "id": "variable9",
            "type": "variable",
            "label": "damage_threshold",
            "centrex": 580,
            "centrey": 46,
            "equation": "1"
        }
    ],
    "arcs": [
        {
            "id": "flow1",
            "type": "flow",
            "start_node_id": "cloud1",
            "end_node_id": "stock1",
            "mid_node_ids": [
                "valve1"
            ]
        },
        {
            "id": "flow2",
            "type": "flow",
            "start_node_id": "stock1",
            "end_node_id": "cloud2",
            "mid_node_ids": [
                "valve2"
            ]
        },
        {
            "id": "flow3",
            "type": "flow",
            "start_node_id": "cloud3",
            "end_node_id": "stock3",
            "mid_node_ids": [
                "valve3"
            ]
        },
        {
            "id": "flow4",
            "type": "flow",
            "start_node_id": "stock3",
            "end_node_id": "cloud4",
            "mid_node_ids": [
                "valve4"
            ]
        },
        {
            "type": "influence",
            "start_node_id": "variable3",
            "end_node_id": "valve1"
        },
        {
            "type": "influence",
            "start_node_id": "variable9",
            "end_node_id": "valve4"
        },
        {
            "type": "influence",
            "start_node_id": "variable7",
            "end_node_id": "valve4"
        },
        {
            "type": "influence",
            "start_node_id": "stock3",
            "end_node_id": "valve4"
        },
        {
            "type": "influence",
            "start_node_id": "variable11",
            "end_node_id": "valve4"
        },
        {
            "type": "influence",
            "start_node_id": "variable13",
            "end_node_id": "valve3"
        },
        {
            "type": "influence",
            "start_node_id": "variable15",
            "end_node_id": "valve5"
        },
        {
            "id": "flow5",
            "type": "flow",
            "start_node_id": "cloud5",
            "end_node_id": "stock5",
            "mid_node_ids": [
                "valve5"
            ]
        },
        {
            "type": "influence",
            "start_node_id": "variable17",
            "end_node_id": "valve5"
        },
        {
            "type": "influence",
            "start_node_id": "stock5",
            "end_node_id": "variable19"
        },
        {
            "type": "influence",
            "start_node_id": "variable19",
            "end_node_id": "valve5"
        },
        {
            "type": "influence",
            "start_node_id": "variable19",
            "end_node_id": "valve1"
        },
        {
            "type": "influence",
            "start_node_id": "variable1",
            "end_node_id": "valve1"
        },
        {
            "type": "influence",
            "start_node_id": "variable19",
            "end_node_id": "valve3"
        },
        {
            "type": "influence",
            "start_node_id": "stock3",
            "end_node_id": "variable7"
        },
        {
            "type": "influence",
            "start_node_id": "stock3",
            "end_node_id": "valve5"
        },
        {
            "type": "influence",
            "start_node_id": "stock1",
            "end_node_id": "valve1"
        },
        {
            "type": "influence",
            "start_node_id": "stock1",
            "end_node_id": "valve2"
        },
        {
            "type": "influence",
            "start_node_id": "variable5",
            "end_node_id": "valve2"
        },
        {
            "type": "influence",
            "start_node_id": "stock3",
            "end_node_id": "valve2"
        },
        {
            "type": "influence",
            "start_node_id": "stock1",
            "end_node_id": "valve3"
        },
        {
            "type": "influence",
            "start_node_id": "variable7",
            "end_node_id": "valve1"
        },
        {
            "type": "influence",
            "start_node_id": "variable9",
            "end_node_id": "variable7"
        }
    ],

"scenarios": {
    "default": {
        "simulation_settings": {
            "start_time": 0,
            "end_time": 50,
            "nstep": 20,
            "display_interval": 1,
            "integration_method": "euler1"
        }
    }
}
};
