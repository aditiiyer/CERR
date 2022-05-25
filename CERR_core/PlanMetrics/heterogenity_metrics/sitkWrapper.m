function filteredOutS = sitkWrapper(sitkLibPath, scan3M, filterType, paramS)
%function filteredOutS = sitkWrapper(sitkLibPath, scan3M, filterType, paramS, planC)
%Calculate image filters using the Simple ITK Python Library
%--------------------------------------------------------------------------
%sitkLibPath - location of sitk python wrappscan to be filtered
%description - Short description string if desired.
%filterType - name of sitk filter
%             Supported options: 'GradientImageFilter','HistogramMatchingImageFilter',...
%             'LaplacianRecursiveGaussianImageFilter',...
%             'N4BiasFieldCorrectionImageFilter',
%             'N4BiasAndHistogramCorrectionImageFilter'.
%paramS: parameters required to calculate the filter
%planC: to convert scan back to cerr
%--------------------------------------------------------------------------
% example usage:
% filterType = 'GradientImageFilter';
% paramS.useImageSpacing = false;
% paramS.useImageDirection = true;
% sitkLibPath = 'C:\Python34\Lib\site-packages\SimpleITK\';
% planC = loadPlanC(cerrFileName,tempdir);
% planC = updatePlanFields(planC);
% % Quality assure
% planC = quality_assure_planC(cerrFileName,planC);
% indexS = planC{end};
%  % Get Scan
%  scanNum  =1;
%  scanM = double(planC{indexS.scan}(scanNum).scanArray) ...
%      - planC{indexS.scan}(scanNum).scanInfo(1).CTOffset;%
%
% sitkWrapper(sitkLibPath, scanM, filterType, paramS)
%
%
% Rutu Pandya, Dec, 16 2019.
%
% Copyright 2010, Joseph O. Deasy, on behalf of the CERR development team.
%
% This file is part of The Computational Environment for Radiotherapy Research (CERR).
%
% CERR development has been led by:  Aditya Apte, Divya Khullar, James Alaly, and Joseph O. Deasy.
%
% CERR has been financially supported by the US National Institutes of Health under multiple grants.
%
% CERR is distributed under the terms of the Lesser GNU Public License.
%
%     This version of CERR is free software: you can redistribute it and/or modify
%     it under the terms of the GNU General Public License as published by
%     the Free Software Foundation, either version 3 of the License, or
%     (at your option) any later version.
%
% CERR is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
% without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
% See the GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with CERR.


% import python module SimpleITK
sitkModule = 'SimpleITK';
numpyModule = 'numpy';
%p = pyenv;

P = py.sys.path;
currentPath = pwd;
cd(sitkLibPath);
sitkFileName = fullfile(sitkLibPath,sitkModule);
numpyFileName = fullfile(sitkLibPath,numpyModule);

try
    if count(P,numpyFileName) == 0
        insert(P,int32(0),numpyFileName);
    end
    py.importlib.import_module(numpyModule)
    if count(P,sitkFileName) == 0
        insert(P,int32(0),sitkFileName);
    end
    py.importlib.import_module(sitkModule)
catch
    disp('SimpleITK module could not be imported, check the path');
end

cd(currentPath);

%origScanSize = size(scanM);
% visualize original scan
%slc = 50;
%figure, imagesc(scanM(:,:,50)), title('orig Image')


% % convert scan to numpy array and integer
% scanPy = py.numpy.array(scanM(:).');
% scanPy = scanPy.astype(py.numpy.int64);
%
% % get original shape of the scan
% origShape = py.numpy.array(size(scanM));
% origShape = origShape.astype(py.numpy.int64);


switch filterType
    case 'GradientImageFilter'
        % paramS inputs needed:
        % useImageSpacing (bool), true by default
        % useImageDirection (bool), true by default
        
        % convert scan to numpy array and integer
        scanPy = py.numpy.array(scan3M);
        scanPy = scanPy.astype(py.numpy.float32);
        
        % get original shape of the scan
        %origShape = py.numpy.array(size(scanM));
        %origShape = origShape.astype(py.numpy.int64);
        
        % reshape numpy array to original shape
        %scanPy = reshape(scanPy,origShape);
        
        % Get image from the array
        itkimg = py.extra.GetImageFromArray(scanPy);
        
        % calculate gradient
        gradient = py.SimpleITK.GradientImageFilter();
        
        if(paramS.useImageSpacing == false)
            gradient.SetUseImageSpacing(paramS.useImageSpacing);
        end
        if(paramS.useImageDirection == false)
            gradient.SetUseImageDirection(paramS.useImageDirection);
        end
        gradImg = gradient.Execute(itkimg);
        
        % extract numpy array from resulting image
        npGradImg = py.extra.GetArrayFromImage(gradImg);
        
        % convert resulting numpy array to matlab array in required shape
        %dblGradResultM = double(py.array.array('d',py.numpy.nditer(npGradImg)));
        %gradMatM = reshape(dblGradResultM,[3,origScanSize]);
        gradMatM = double(npGradImg);
        gradMatM = permute(gradMatM,[2,3,4,1]);
        
        %             %visualize
        %             size(gradMatM)
        %             figure, imagesc(gradMatM(:,:,50,1))
        %             figure, imagesc(gradMatM(:,:,50,2))
        %             figure, imagesc(gradMatM(:,:,50,3))
        
        filteredOutS.xGradient = gradMatM(:,:,:,1);
        filteredOutS.yGradient = gradMatM(:,:,:,2);
        filteredOutS.zGradient = gradMatM(:,:,:,3);
        
        
    case 'LaplacianRecursiveGaussianImageFilter'
        
        % convert scan to numpy array and integer
        % scanPy = py.numpy.array(scanM(:).');
        scanPy = py.numpy.array(scan3M);
        scanPy = scanPy.astype(py.numpy.float32);
        
        % get original shape of the scan
        %origShape = py.numpy.array(size(scanM));
        %origShape = origShape.astype(py.numpy.int64);
        
        % reshape numpy array to original shape
        %scanPy = reshape(scanPy,origShape);
        
        % Get image from the array
        itkimg = py.extra.GetImageFromArray(scanPy);
        
        % Set Image spacing
        zSpacing = paramS.VoxelSize_mm.val(3);
        xSpacing = paramS.VoxelSize_mm.val(1);
        ySpacing = paramS.VoxelSize_mm.val(2);
        itkimg.SetSpacing([zSpacing, ySpacing, xSpacing]);
        
        % calculate gradient
        logRecursiveFilt = py.SimpleITK.LaplacianRecursiveGaussianImageFilter();
        
        logRecursiveFilt.SetNormalizeAcrossScale(true)
        
        sigmaVal = paramS.Sigma_mm.val;
        logRecursiveFilt.SetSigma(sigmaVal);
        
        % Execute the filter
        logImg = logRecursiveFilt.Execute(itkimg);
        
        % extract numpy array from resulting image
        npLogImg = py.extra.GetArrayFromImage(logImg);
        
        % convert resulting numpy array to matlab array in required shape
        %dblLogResultM = double(py.array.array('d',py.numpy.nditer(npLogImg)));
        %logMatM = reshape(dblLogResultM,origScanSize);
        
        logMatM = double(npLogImg);
        
        filteredOutS.logImg3M = logMatM;
        
        
    case 'HistogramMatchingImageFilter'
        % paramS inputs needed:
        % numHistLevel (int), paramS.numMatchPts (int),
        % ThresholdAtMeanIntensityOn (bool),
        % refImgPath (char vector)
        
        % convert scan to numpy array and integer
        scanPy = py.numpy.array(scan3M);
        scanPy = scanPy.astype(py.numpy.float32);
        
        % get original shape of the scan
        %origShape = py.numpy.array(size(scanM(:)'));
        %origShape = origShape.astype(py.numpy.int64);
        
        % reshape numpy array to original shape
        %scanPy = reshape(scanPy,origShape);
        
        % Get image from the array
        
        srcItkImg = py.extra.GetImageFromArray(scanPy);
        
        
        %             srcItkImg = py.SimpleITK.ReadImage('E:\data\TumorAware_MR\nrrdScanFormat.nrrd');
        
        % get ref image
        maskImgPath = fullfile(getCERRPath,'ModelImplementationLibrary/SegmentationModels/referenceImages');
        if isfield(paramS,'refImg') && ~isempty(paramS.refImg.val)
            [refPath,~,~,] = fileparts(paramS.refImg.val);
            if isempty(refPath)
                maskImgPath = fullfile(maskImgPath,paramS.refImg.val);
            else
                maskImgPath = paramS.refImg.val;
            end
            refItkImg = py.extra.ReadImage(maskImgPath);
            refItkImg = py.extra.Cast(refItkImg,py.SimpleITK.sitkFloat32);
            %Adjust to RTOG-compliant orientation 
            maskPy = py.extra.GetArrayFromImage(refItkImg);
            mask3M = single(maskPy);
            mask3M = permute(mask3M,[2,3,1]);
            mask3M = flip(flip(mask3M,1),2);
            mask3M = flip(mask3M,3);
            maskPy = py.numpy.array(mask3M);
            refItkImg = py.extra.GetImageFromArray(maskPy);
        elseif isfield(paramS,'refImgMat') && ~isempty(paramS.refImgMat.val)
            maskPy = py.numpy.array(paramS.refImgMat.val);
            maskPy = maskPy.astype(py.numpy.float32);   
            % Get image from the array
            refItkImg = py.extra.GetImageFromArray(maskPy);
        else
            error('Reference image not specified for histogram matching')
        end
        
        %refNumElems = int64(py.numpy.prod(refScanPy.shape));
        %refShape = py.numpy.array([1,refNumElems]);
        %refScanPy = refScanPy.astype(py.numpy.int64);        
        % reshape numpy array to original shape
        %refScanPy = reshape(refScanPy,refShape);
        
        
        
        %refItkImg = py.SimpleITK.reshape(refItkImg, scanPy);
        % execute Histogram Matching
        matcher = py.SimpleITK.HistogramMatchingImageFilter();
        matcher.SetNumberOfHistogramLevels(uint32(paramS.numHistLevel.val));
        matcher.SetNumberOfMatchPoints(uint32(paramS.numMatchPts.val));
        if(paramS.thresholdAtMeanIntensityOn.val)
            matcher.ThresholdAtMeanIntensityOn();
        end
        matchedImg = matcher.Execute(srcItkImg,refItkImg);
        
        % extract numpy array from resulting image
        npHistImg = py.extra.GetArrayFromImage(matchedImg);
        
        % convert resulting numpy array to matlab array in required shape
        %dblHistResultM = double(py.array.array('d',py.numpy.nditer(npHistImg)));
        %histMatM = reshape(dblHistResultM,[origScanSize(1),origScanSize(2),origScanSize(3)]);
        histMatM = double(npHistImg);
        
        filteredOutS.histMatchedImage = histMatM;
        
        %             %visualize
        %             size(histMatM)
        %             figure, imagesc(histMatM(:,:,slc,1))
        %             figure, imagesc(histMatM(:,:,slc,2))
        %             figure, imagesc(histMatM(:,:,slc,3))
        
    case 'N4BiasFieldCorrectionImageFilter'

        % Convert to sitk image
        scanPy = py.numpy.array(scan3M);
        scanPy = scanPy.astype(py.numpy.float32);
        srcItkImg = py.extra.GetImageFromArray(scanPy);

        % Get mask
        if isfield(paramS,'maskImg') && ~isempty(paramS.maskImg.val)
            maskImgPath = fullfile(paramS.maskImg.val);
            maskImg = py.extra.ReadImage(maskImgPath);
            maskImg = py.extra.Cast(maskImg,py.SimpleITK.sitkFloat32);
            %Adjust to RTOG-compliant orientation 
            maskPy = py.extra.GetArrayFromImage(maskImg);
            mask3M = single(maskPy);
            mask3M = permute(mask3M,[2,3,1]);
            mask3M = flip(flip(mask3M,1),2);
            mask3M = flip(mask3M,3);
            maskPy = py.numpy.array(mask3M);
            maskImg = py.extra.GetImageFromArray(maskPy);
        else
            %Use defaults
            maskImg = py.SimpleITK.OtsuThreshold(srcItkImg,...
                uint8(0),uint8(1),uint32(200));
        end

        corrector = py.SimpleITK.N4BiasFieldCorrectionImageFilter()

        % Get optional parameters
        if isfield(paramS,'shrinkFactor') && paramS.shrinkFactor.val > 1
            shrink = paramS.shrinkFactor.val;
            srcItkImg = py.SimpleITK.Shrink(srcItkImg,...
                shrink*srcItkImg.GetDimension());
            maskImg = py.SimpleITK.Shrink(maskImg,...
                shrink*srcItkImg.GetDimension());
        end

        if isfield(paramS,'numFittingLevels') 
            numFitLevels = paramS.numFittingLevels.val;
        else
            numFitLevels = 4;
        end

        if isfield(paramS,'numIterations')
            numIterationsV = paramS.numIterations.val; %Vector of values per fit level
            maxIterations = int32(numIterationsV) * numFitLevels;
            corrector.SetMaximumNumberOfIterations(maxIterations);
        end


        % Apply bias correction
        outImg = corrector.Execute(srcItkImg, maskImg);

        % Convert to matlab array 
        npCorrectedImg = py.extra.GetArrayFromImage(outImg);
        correctedImg3M = double(npCorrectedImg);
        filteredOutS.biasCorrectedImage = correctedImg3M;


    case 'N4BiasAndHistogramCorrectionImageFilter'
        filteredOutS = sitkWrapper(sitkLibPath, scan3M, ...
            'N4BiasFieldCorrectionImageFilter', paramS);
        correctedScan3M = filteredOutS.biasCorrectedImage;
        filteredOutS = sitkWrapper(sitkLibPath, correctedScan3M, ...
            'HistogramMatchingImageFilter', paramS);

    otherwise
        
        msgStr = [filterType,' not defined. Add it to sitkWrapper.m'];
        error(msgStr)
end


