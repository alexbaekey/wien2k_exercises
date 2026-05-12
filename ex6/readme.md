ex6

# Band gaps

| Band gap (eV) | Si | GaAs | InAs |
|---|---:|---:|---:|
| PBE noSOC | 0.559 | 0.500 | 0.000 |
| PBE withSOC | 0.543 | 0.391 | 0.000 |
| HSE noSOC | 1.149 | 1.324 | 0.403 |
| HSE withSOC | 1.133 | 1.214 | 0.285 |


# SCF runtimes

| SCF time (minutes) | Si | GaAs | InAs |
|---|---:|---:|---:|
| PBE noSOC | 0.08 | 0.18 | 0.37 |
| PBE withSOC | 0.02 | 0.16 | 0.62 |
| HSE noSOC | 3.97 | 24.29 | 44.64 |
| HSE withSOC | 10.64 | 48.48 | 91.95 |

# SCF summaries

## InAs
```text
HSE noSOC
:ENE  : ********** TOTAL ENERGY IN Ry =       -16288.40462968
:FER  : F E R M I - ENERGY(TETRAH.M.)=   0.3281783686
:BAN00021:  21    0.667032    0.667032  0.00000000
:GAP (global)   :  0.029592 Ry =     0.403 eV (accurate value if proper k-mesh)

HSE withSOC
:ENE  : ********** TOTAL ENERGY IN Ry =       -16288.40573881
:FER  : F E R M I - ENERGY(TETRAH.M.)=   0.3365936983
:BAN00039:  39    0.678256    0.737761  0.00000000
:GAP (this spin):  0.020982 Ry =     0.285 eV (accurate value if proper k-mesh)
```

## Si
```text
HSE noSOC
:ENE  : ********** TOTAL ENERGY IN Ry =        -1160.31936449
:FER  : F E R M I - ENERGY(TETRAH.M.)=   0.3837810870
:BAN00007:   7    0.626100    0.692326  0.00000000
:GAP (global)   :  0.084481 Ry =     1.149 eV (accurate value if proper k-mesh)

HSE withSOC
:ENE  : ********** TOTAL ENERGY IN Ry =        -1160.31936962
:FER  : F E R M I - ENERGY(TETRAH.M.)=   0.3849502786
:BAN00013:  13    0.626944    0.692885  0.00000000
:GAP (this spin):  0.083311 Ry =     1.133 eV (accurate value if proper k-mesh)
```

## GaAs
```text
HSE noSOC
:ENE  : ********** TOTAL ENERGY IN Ry =        -8410.10766100
:FER  : F E R M I - ENERGY(TETRAH.M.)=   0.3371081878
:BAN00018:  18    0.667594    0.667594  0.00000000
:GAP (global)   :  0.097284 Ry =     1.324 eV (accurate value if proper k-mesh)

HSE withSOC
:ENE  : ********** TOTAL ENERGY IN Ry =        -8410.10783009
:FER  : F E R M I - ENERGY(TETRAH.M.)=   0.3451244400
:BAN00033:  33    0.672007    0.744187  0.00000000
:GAP (this spin):  0.089240 Ry =     1.214 eV (accurate value if proper k-mesh)
```
