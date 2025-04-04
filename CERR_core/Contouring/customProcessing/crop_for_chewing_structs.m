function [bbox3M, planC] = crop_for_chewing_structs(planC,paramS,varargin)
% Custom crop function for chewing structures segmentation model
% AI 10/04/19

indexS = planC{end};
strC = {planC{indexS.structures}.structureName};
bboxIdx = [];

%% Return bounding box if it exists
if isfield(paramS,'saveStrToPlanCFlag') && paramS.saveStrToPlanCFlag
    if isfield(paramS,'outStrName')
        outStrName = paramS.outStrName;
    else
        outStrName = 'crop_for_chewing_structs';
    end
    bboxIdx = getMatchingIndex(outStrName,strC,'EXACT');
end
if ~isempty(bboxIdx)
    bbox3M = getStrMask(bboxIdx,planC);
else
    %% Get mask of pt outline
    outerStr = paramS.structureName; %pt outline
    strNum = getMatchingIndex(outerStr,strC,'EXACT');
    if isempty(strNum)
        %Generate pt outline
        scanNum = 1;
        scan3M = double(getScanArray(scanNum,planC));
        CToffset = planC{indexS.scan}(scanNum).scanInfo(1).CTOffset;
        scan3M = scan3M - CToffset;
        outerMask3M = getPatientOutline(scan3M,1:size(scan3M,3),-400);
        planC = maskToCERRStructure(outerMask3M,0,scanNum,outerStr,planC);
        strC = {planC{indexS.structures}.structureName};
        strNum = length(strC);
    else
        [outerMask3M, planC]= getStrMask(strNum,planC);
    end

    %% Get S-I limits
    % ----- Decommissioned----
    %[noseSliceNum, planC] = getNoseSlice(outerMask3M,planC,outerStr);
    %[maxs, mins, planC] = ...
    %getShoulderStartSlice(outerMask3M,planC,outerStr,noseSliceNum); %Crop to shoulder slice
    %--------------------------
    %Use all slices
    mins = find(sum(sum(outerMask3M))>0,1,'first');
    %mins = 1;
    maxs = size(outerMask3M,3);

    %% Get head extent
    zStart = planC{indexS.scan}(1).scanInfo(mins).zValue;
    zV = [planC{indexS.scan}(1).scanInfo(mins:end).zValue];
    headSizLimit = paramS.headSizeLimitCm;
    zDiffV = (zV-zStart);
    [~, endSlc] = min(abs(zDiffV-headSizLimit));
    endSlc = endSlc + mins;
    if maxs<endSlc
        SIextent = zV(maxs) - zV(mins);
        warning(['Input scan S-I extent = %g cm. Model performance on',...
            ' cropped scans (S-I extent < %g cm) is untested.'],...
            SIextent,headSizLimit);
        endSlc = min(endSlc,maxs);
    end

    %% Get A,P extents
    minrV = nan(size(outerMask3M,3),1);
    maxrV = minrV;
    mincV = minrV;
    maxcV = minrV;
    for n = 1:endSlc
        maskSlcM = outerMask3M(:,:,n);
        if any(maskSlcM(:))
            [minrV(n),maxrV(n),mincV(n),maxcV(n)] = compute_boundingbox(outerMask3M(:,:,n));
        end
    end

    minr = round(prctile(minrV,5));
    maxr = round(median(maxrV,'omitnan'));
    width = maxr-minr+1;
    maxr = round(maxr-.25*width);

    %% Get L,R extents
    [~,slcRmin] = min(abs(minrV-minr));
    minc = mincV(slcRmin);
    maxc = maxcV(slcRmin);

    %% Return bounding box
    bbox3M = false(size(outerMask3M));
    bbox3M(minr:maxr,minc:maxc,mins:maxs) = true;
end

end