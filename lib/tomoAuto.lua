--[[==========================================================================#
# This is a program to automate the alignment of a raw tilt series, use the   #
# program RAPTOR to make a final alignment, use IMOD to estimate the defocus  #
# and then correct the CTF by appropriate phase flipping, and then finally    #
# using eTomo to create the reconstruction.                                   #
#-----------------------------------------------------------------------------#
# Author: Dustin Morado                                                       #
# Written: February 27th 2014                                                 #
# Contact: Dustin.Morado@uth.tmc.edu                                          #
#-----------------------------------------------------------------------------#
# Arguments: arg[1] = image stack file <filename.st>                          #
#            arg[2] = fiducial size in nm <integer>                           #
#            arg[3] = table with option flags from getOpts                    #
#==========================================================================--]]
local tomoAutoDir = os.getenv('TOMOAUTOROOT')
package.path = package.path .. ';' .. tomoAutoDir .. '/lib/?.lua;'
local comWriter = assert(require 'comWriter')
local tomoLib = assert(require 'tomoLib')
local lfs, os, string = lfs, os, string

local tomoAuto = {}

function tomoAuto.reconstruct(stackFile, fidSize, Opts)
local filename = string.sub(stackFile, 1, -4)

tomoLib.checkFreeSpace(startDir)
assert(lfs.mkdir(filename),'\nCould not make root directory\n')
assert(os.execute('mv ' .. stackFile .. ' ' .. filename), 
       '\nCould not move stackfile to file directory\n')
assert(lfs.chdir(filename), '\nCould not change to file directory\n')

local startDir = lfs.currentdir()
local header = tomoLib.findITP(stackFile, fidSize)
if Opts.d_ then header.defocus = Opts.d_ end
comWriter.write(stackFile, header, Opts.L_)

if Opts.g then
   local file = io.open('tilt.com', 'a')
   file:write('UseGPU 0\n')
   file:close()
end

if Opts.z_ then
   local file = io.open('tilt.com', 'r')
   local contents = file:read('*a')
   contents  = contents:gsub('THICKNESS (%d+)', 'THICKNESS ' 
           .. tostring(Opts.z_))
   file = io.open('tilt.com', 'w')
   file:write(contents)
   file:close(); file = nil
end

if feiLabel == 'Fei' then
   local file = io.open('ctfplotter.com', 'r')
   local contents = file:read('*a')
   contents = contents:gsub('K2background%/polara%-K2%-2013%.ctg', 
      'CCDBackground/polara-CCD-2012.ctg')
   file = io.open('ctfplotter.com', 'w')
   file:write(contents)
   file:close(); file = nil
end

io.write('Running IMOD extracttilts for ' .. filename .. '\n')
tomoLib.runCheck('extracttilts -input ' .. stackFile .. ' -output '
                 .. filename .. '.rawtlt > /dev/null')

assert(lfs.mkdir('finalFiles'),
       '\nCould not make finalFiles directory\n')
assert(os.execute('cp ' .. stackFile .. ' finalFiles'),
       '\nCould not copy files\n')

-- We should always remove the Xrays from the image using ccderaser
io.write('Running ccderaser\n')
tomoLib.runCheck('submfg -s -t ccderaser.com')
tomoLib.writeLog(filename)
assert(tomoLib.isFile(filename .. '_fixed.st'),
       '\nccderaser failed, see log\n')
assert(os.execute('mv ' .. stackFile .. ' ' .. filename .. '_orig.st'), 
       '\nCould not move file\n')
assert(os.execute('mv ' .. filename .. '_fixed.st ' .. stackFile),
       '\nCould not move file\n')

io.write('Running Coarse Alignment for ' .. stackFile .. '\n')
tomoLib.runCheck('submfg -s -t tiltxcorr.com xftoxg.com newstack.com')
tomoLib.writeLog(filename)
assert(tomoLib.isFile(filename .. '.preali'),
       '\ncoarse alignment failed see log\n')

-- Now we run RAPTOR to produce a succesfully aligned stack
tomoLib.checkFreeSpace(startDir)
io.write('Now running RAPTOR (please be patient this may take some time)\n')
tomoLib.runCheck('submfg -t raptor1.com')
tomoLib.writeLog(filename)
assert(tomoLib.isFile('raptor1/align/' .. filename .. '.ali'),
       '\nRAPTOR alignment failed see log\n')
assert(os.execute('mv raptor1/align/' .. filename .. '.ali .'), 
       '\nCould not move file\n')
assert(os.execute('mv raptor1/IMOD/' .. filename .. '.tlt .'),
       '\nCould not move file\n')
assert(os.execute('mv raptor1/IMOD/' .. filename .. '.xf .'),
       '\nCould not move file\n')
io.write('RAPTOR alignment for ' .. stackFile .. ' SUCCESSFUL\n')

if not tomoLib.checkAlign(filename, nz) then
   io.stderr:write('RAPTOR has cut too many sections. Bad Data!')
   tomoLib.writeLog(filename)
   return 1
end

-- Ok for the new stuff here we add CTF correction
-- noise background is now set in the global config file
if Opts.c then
   tomoLib.checkFreeSpace(startDir)
   io.write('Now running ctfplotter and ctfphaseflip for CTF correction\n')

   if Opts.p_ then
      tomoLib.runCheck('submfg -s -t ctfplotter.com')
      assert(tomoLib.isFile(filename .. '.defocus'),
             '\nCTFplotter failed see log\n')
      tomoLib.runCheck('splitcorrection ctfcorrection.com')
      tomoLib.runCheck('processchunks -g -C "0 0 0" -T "600 0" ' 
                       .. Opts.p_ .. ' ctfcorrection')
      tomoLib.writeLog(filename)
   else
      tomoLib.runCheck('submfg -t ctfplotter.com ctfcorrection.com')
      assert(tomoLib.isFile(filename .. '_ctfcorr.ali'),
             '\nCTFcorrection failed see log\n')
      tomoLib.writeLog(filename)
   end

   assert(os.execute('mv ' .. filename .. '.ali ' .. filename .. '_first.ali'),
          '\nCould not move files\n')
   assert(os.execute('mv ' .. filename .. '_ctfcorr.ali ' .. filename .. '.ali'),
          '\nCould not move files\n')
end

-- Now we use RAPTOR to make a fiducial model to erase the gold in the stack
io.write('Now running RAPTOR to track gold to erase particles\n')
tomoLib.checkFreeSpace(startDir)
tomoLib.runCheck('submfg -t raptor2.com')
assert(tomoLib.isFile('raptor2/IMOD/' .. filename .. '.fid.txt'),
       '\nCould not make fiducial model see log.\n')
assert(os.execute('mv raptor2/IMOD/' .. filename .. '.fid.txt '
       .. filename .. '_erase.fid'), '\nCould not move files\n')

if not tomoLib.checkAlign(filename, nz) then
   io.stderr:write('RAPTOR has cut too many sections. Bad Data!')
   tomoLib.writeLog(filename)
   return 1
end

-- Make the erase model more suitable for erasing gold
tomoLib.runCheck('submfg -t model2point.com point2model.com')
tomoLib.writeLog(filename)
assert(tomoLib.isFile(filename .. '_erase.scatter.fid'),
       '\nError making point model from RAPTOR text model see log.\n')

assert(os.execute('mv ' .. filename .. '_erase.fid ' .. filename 
       .. '_erase.fid_orig'), '\nCould not move file\n')
assert(os.execute('mv ' .. filename .. '_erase.scatter.fid ' ..filename 
       .. '_erase.fid'), '\nCould not move file\n')

io.write('Now erasing gold from aligned stack\n')
tomoLib.runCheck('submfg -t gold_ccderaser.com')
tomoLib.writeLog(filename)
assert(tomoLib.isFile(filename .. '_erase.ali'),
       '\nCould not erase gold see log.\n')

assert(os.execute('mv ' .. filename .. '.ali ' .. filename .. '_second.ali'),
       '\nCould not move file.\n')
assert(os.execute('mv ' .. filename .. '_erase.ali ' .. filename .. '.ali'),
       '\nCould not move file.\n')

if Opts.p_ then
   tomoLib.runCheck('splittilt -n ' .. Opts.p_ .. ' tilt.com')
   tomoLib.runCheck('processchunks -g -C "0 0 0" -T "600 0" '
                    .. Opts.p_ .. ' tilt')
   tomoLib.writeLog(filename)
   assert(tomoLib.isFile(filename .. '_full.rec'),
          '\nError running tilt reconstruction see log.\n')
else
   tomoLib.runCheck('submfg -s -t tilt.com')
   tomoLib.writeLog(filename)
   assert(tomoLib.isFile(filename .. '_full.rec'),
          '\nError running tilt reconstruction see log.\n')
end

tomoLib.runCheck('clip rotx ' .. filename .. '_full.rec ' .. filename 
                 .. '_full.rec')
tomoLib.runCheck('binvol -binning 4 ' .. filename .. '_full.rec '
                 .. filename .. '.bin4 2>&1 /dev/null')
tomoLib.runCheck('binvol -binning 4 -zbinning 1 ' .. filename .. '.ali '
                 .. filename .. '.ali.bin4 2>&1 /dev/null')

if Opts.p_ then
   tomoLib.runCheck('chunksetup -p 15 -o 4 nad_eed_3d.com ' .. filename 
                    .. '.bin4 ' .. filename .. '.bin4.nad')
   tomoLib.runCheck('processchunks -g -C "0 0 0" -T "600 0" ' 
                    .. Opts.p_ .. ' nad_eed_3d')
   tomoLib.writeLog(filename)
else
   tomoLib.runCheck('submfg -s -t nad_eed_3d.com')
   tomoLib.writeLog(filename)
end

assert(tomoLib.isFile(filename .. '.bin4.nad'),
       '\nError computing NAD filter, see log.\n')
tomoLib.medNfilter(filename .. '.bin4.nad', 7)
tomoLib.writeLog(filename)
assert(tomoLib.isFile(filename .. '.bin4.nad7'),
       '\nError computing med7 filter\n')

io.write('Now running file and space cleanup\n')
ctfPlotCom = io.open('ctfplotter.com', 'r')
ctfPlot = ctfPlotCom:read('*a')
ctfPlotCom:close()
ctfNewPlotCom = io.open('ctfplotter.com', 'w')
ctfNewPlot = ctfPlot:gsub('SaveAndExit', '#SaveAndExit')
ctfNewPlot = ctfNewPlot:gsub('AutoFitRangeAndStep', '#AutofitRangeAndStep')
ctfNewPlotCom:write(ctfNewPlot)
ctfNewPlotCom:close()

assert(os.execute('mv ' .. filename .. '_full.rec ' -- full reconstruction
                 .. filename .. '.bin4 ' -- for checking
                 .. filename .. '.tlt ' -- for ctfplotter.com
                 .. filename .. '.bin4.nad ' -- for checking
                 .. filename .. '.bin4.nad7 ' -- for picking subvols
                 .. filename .. '_first.ali ' -- for ctfplotter.com
                 .. filename .. '.ali.bin4 ' -- for checking
                 .. filename .. '.defocus ' -- for ctfplotter.com
                 .. 'ctfplotter.com tomoAuto.log finalFiles'),
       '\nCould not move final files.\n')
assert(os.execute('rm *.com *.log ' .. filename .. '*'),
       '\nCould not remove command and log files.\n')
assert(os.execute('rm -rf raptor*'), '\nCould not remove raptor files.\n')
assert(os.execute('mv finalFiles/* .'), '\nCould not move files.\n')
assert(os.execute('rmdir finalFiles'), '\nCould not remove directory.\n')
assert(os.execute('mv ' .. filename .. '_first.ali ' .. filename .. '.ali'),
      '\nCould not move files.\n')
lfs.chdir('..')
io.write('tomoAuto complete for ' .. stackFile .. '\n')
end
return tomoAuto
