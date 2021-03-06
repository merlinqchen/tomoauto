#tomoAuto
## Version 0.2.10
### About
tomoAuto is a Lua program to automate the alignment, correction and
recontstruction of cryo-electron tomography (Cryo-ET) data. Coupled with
high-throughput collection, tomoAuto drastically speeds up data processing so
that more time can be spent on data analysis.

tomoAuto is simply a script that handles the use of several popular software
packages in the field and simplifies their use in collection by globalizing the
command line calls and configurations. It has been running in some form or
fashion in our lab for the last 3 years with good results. 

It is a very rough release and has many TODOs that have yet to be implemented.  

### Change Log
#### 0.2.10
 * Changed final files kept to save space and rely on options available in 3dmod
 * As of IMOD 4.7.9 autofidseed works better than RAPTOR to generate the
   fiducial seed model and is now default. RAPTOR can still be used by passing
   the appropriate option (see tomoauto --help).
#### 0.2.0
 * Added mode option to stop at alignment, ccderase, or to only perform
   reconstruction
 * Stopped using RAPTOR to generate the alignment, now it only produces the
   fiducial seed model and then IMOD performs the alignment.
 * No longer using a folder with the basename which helps keep things clean and
   organized when using the align and then the reconstruct mode.
 * Removed all batch commands, handle them yourself with the shell.
 * Added programs to create a newstack from drift-corrected images collected by
   dose-fractionation.
 * Added a pretty substantial lua module to handle MRC files.
 * Most of the IMOD commands handle multi-core automatically so removed -p
   option.

---

### Software used

**[IMOD](http://bio3d.colorado.edu/imod/)**

**[RAPTOR]
(http://fernandoamat.com/index.php?option=com_content&view=article&id=49:raptor&catid=38:bioimaging&Itemid=56)**

**[TOMO3D]
(https://sites.google.com/site/3demimageprocessing/software)**

----

### Credit and Acknowledgements
If you use this software please read the license file and use the software
appropriately. Also there are many papers to cite if you use this software in
your research. 

**IMOD:**

 Kremer J.R., D.N. Mastronarde and J.R. McIntosh (1996) Computer
visualization of three-dimensional image data using IMOD. J. Struct. Biol.
116:71-76. 

[PubMed](http://www.ncbi.nlm.nih.gov/pubmed/8742726)

Mastronarde, D. N. (1997) Dual-axis tomography: an approach with alignment 
methods that preserve resolution. J. Struct. Biol. 120:343-352.

[PubMed](http://www.ncbi.nlm.nih.gov/pubmed/9441937)

**RAPTOR**

F. Amat, F. Moussavi,L.R. Comolli, G. Elidan, K.H. Downing, M. Horowitz (2008) 
"Markov random field based automatic image alignment for electron tomography". 
J. Struct. Biol. 161: 260-275

[PubMed](http://www.ncbi.nlm.nih.gov/pubmed/17855124)

**TOMO3D**

J.I. Agulleiro, J.J. Fernandez (2011) Fast tomographic reconstruction on
multicore computers. Bioinformatics 27:582–583.

[PubMed](http://www.ncbi.nlm.nih.gov/pubmed/21172911)

J.I. Agulleiro, E.M. Garzon, I. Garcia, J.J. Fernandez. (2010)
Vectorization with SIMD extensions speeds up reconstruction in electron
tomography. J. Struct. Biol. 170:570-575.

[PubMed](http://www.ncbi.nlm.nih.gov/pubmed/20085820)

JI Agulleiro, JJ Fernandez. (2012) Evaluation of a multicore-optimized
implementation for tomographic reconstruction. PLoS ONE  7(11):e48261.
