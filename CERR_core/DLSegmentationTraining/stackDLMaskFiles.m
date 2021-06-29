function outC = stackDLMaskFiles(outPath,outFmt,passedScanDim)
% stackDLMaskFiles.m Reads output mask files and returns 3D stack.
%--------------------------------------------------------------------------
%INPUTS:
% outPath       : Path to generated H5 files
%                 Note: Assumes output filenames are of the form:
%                 prefix_slice# if  passedScanDim = '2D' and
%                 prefix_3D if passedScanDim = '3D'.
%------------------------------------------------------------------------
% AI 6/29/21

switch outFmt
    
    case 'H5'
        outC = stackHDF5Files(outPath,passedScanDim);
        
    case 'NRRD'
        
        dirS = dir(fullfile(outPath,'outputNRRD','*.nrrd'));
        fileNameC = {dirS.name};
        ptListC = unique(strtok(fileNameC,'_'));
        outC = cell(length(ptListC),1);
        
        for p = 1:length(ptListC)
            
            %Assumes 3D mask file
            fileName = fullfile(outPath,'outputNRRD',fileNameC{1});
            mask3M = nrrdread(fileName);
            outC{p} = mask3M;
        end
        
    otherwise
        
        error('invalid output format %s',outFmt);
        
end
