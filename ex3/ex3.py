import numpy as np
import pandas as pd
from matplotlib import pyplot as plt
from matplotlib.collections import LineCollection
from matplotlib import colors

##### preprocessing
### import data
df_band = pd.read_csv("band_structure.txt",
                sep=r'\s+',  # 'delim_whitespace' keyword in pd.read_csv is deprecated
                comment='#',
                names=["k", "E"])

k = df_band["k"]
E = df_band["E"]

### translate max of lower band to E=0 (Fermi Energy) 
E_lowerband = E[0:150]
E_lowerband_max = max(E_lowerband)
# energy shift to Fermi energy
E = E + abs(E_lowerband_max)

### import data
df_qtl = pd.read_csv("qtl.txt",
                sep=r'\s+',  # 'delim_whitespace' keyword in pd.read_csv is deprecated
                comment='#',
                names=["E", "atom", "qtl_tot", "qtl_s", "qtl_p", "qtl_d"])

df_atom1 = df_qtl[df_qtl['atom'] == 1].reset_index(drop=True)
df_atom2 = df_qtl[df_qtl['atom'] == 2].reset_index(drop=True)
df_atomI = df_qtl[df_qtl['atom'] == 3].reset_index(drop=True) # interstitial

atom1_contribution = df_atom1['qtl_tot']
atom2_contribution = df_atom2['qtl_tot']
atomI_contribution = df_atomI['qtl_tot'] # interstitial

### plot a (atom 1)
plt.plot(k,E,color='black')
plt.scatter(k, E, s=(atom1_contribution)*150, facecolors='none', 
            alpha=0.7, edgecolor="purple")
plt.xlim(k.min(), k.max())
plt.ylim(E.min()-0.1, E.max()+0.1)
plt.savefig('results/a.png')
plt.clf()


### plot b (atom 2)
plt.plot(k,E,color='black')
plt.scatter(k, E, s=(atom2_contribution)*150, facecolors='none', 
            alpha=0.7, edgecolor="green")
plt.xlim(k.min(), k.max())
plt.ylim(E.min()-0.1, E.max()+0.1)
plt.savefig('results/b.png')
plt.clf()

### plot c (interstitial)
plt.plot(k,E,color='black')
plt.scatter(k, E, s=(atomI_contribution)*150, facecolors='none', 
            alpha=0.7, edgecolor="blue")
plt.xlim(k.min(), k.max())
plt.ylim(E.min()-0.1, E.max()+0.1)
plt.savefig('results/c.png')
plt.clf()

# plot d [(A1-A2)/(A1+A2)]
x = k
y = E
z = (atom1_contribution-atom2_contribution)/(atom1_contribution+atom2_contribution)

points = np.array([x, y]).T.reshape(-1, 1, 2)
segments = np.concatenate([points[:-1], points[1:]], axis=1)
norm = colors.Normalize(vmin=-1, vmax=1)
lc = LineCollection(segments, cmap='rainbow', norm=norm, linewidth=4)
#lc = LineCollection(segments, cmap='rainbow', linewidth=4)
lc.set_array(z) # 'z' determines the color mapping
fig,ax = plt.subplots()
ax.add_collection(lc)
ax.set_xlim(x.min(), x.max())
ax.set_ylim(y.min()-0.1, y.max()+0.1)
cax = fig.add_axes([0.36, 0.5, 0.3, 0.03]) # left, bottom, width, height
cbar = fig.colorbar(lc, cax=cax, orientation="horizontal")
#cbar.set_ticks(np.linspace(z1.min(), z1.max(), 2))
cbar.set_ticks(np.linspace(-1, 1, 3))
cbar.ax.tick_params(labelsize=12)
fig.savefig('results/d.png')
fig.clf()



