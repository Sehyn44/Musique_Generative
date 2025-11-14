import numpy as np
import matplotlib.pyplot as plt

def Exp_Decay(duration, tau=0.5, Fs=44800):
    n = int(duration * Fs)
    out = np.zeros(n)
    for i in range(n):
        out[i] = (np.exp(-float(i) / (tau * Fs)) - np.exp(-float(n) / (tau * Fs)))/(1 - np.exp(-float(n) / (tau * Fs)))
    return out

def Soft_Decay(duration, tau=0.5, Fs=44800):
    ## Must Tau >= 0.25 for soft decay to reach 0 at the end of duration
    n = int(duration * Fs)
    out = np.zeros(n)
    for i in range(n):
        out[i] = (1 - (i+1)/n)**(tau)
    return out

duration = 0.5


### Exponential Decay plot ###

plt.figure(1)
plt.title("Exponential Decay")
### for tau in [0.1, 5]:
    ### plt.plot(Exp_Decay(duration, tau=tau), label=fr'$\tau={tau}$s')
    
plt.plot(Exp_Decay(duration, tau=10), label=fr'Exp $\tau={10}$s')

soft_tau = 0.1
plt.plot(Soft_Decay(duration, tau=soft_tau), label=fr'Exp $\tau={soft_tau}$s', linestyle ='--')
plt.legend(loc="lower left")
plt.grid()


### Soft Decay plot ###
'''
plt.figure(2)
plt.title("Soft Decay")
for tau in [0.1, 0.25, 0.5, 1, 2, 5]:
    plt.plot(Soft_Decay(duration, tau=tau), label=fr'$\tau={tau}$s')
plt.legend(loc="lower left")
plt.grid()
'''




### Fig show  ###
plt.show()

