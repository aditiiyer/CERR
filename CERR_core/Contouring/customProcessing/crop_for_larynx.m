function [bbox3M, planC] = crop_for_larynx(planC,paramS,varargin)
% Custom crop function for larynx segmentation model
% AI 10/04/19

indexS = planC{end};
strC = {planC{indexS.structures}.structureName};
bboxIdx = [];

%% Return bounding box if it exists
if isfield(paramS,'saveStrToPlanCFlag') && paramS.saveStrToPlanCFlag
    if isfield(paramS,'outStrName')
        outStrName = paramS.outStrName;
    else
        outStrName = 'crop_for_larynx';
    end
    bboxIdx = getMatchingIndex(outStrName,strC,'EXACT');
end
if ~isempty(bboxIdx)
    bbox3M = getStrMask(bboxIdx,planC);
else
    %% Create union of masseters (left & right) and medial pterygoids (left & right)
    unionStrListC = paramS.structureName.chewingStructures;

    for k = 1:length(unionStrListC)
        idx = getMatchingIndex(unionStrListC{k},strC,'EXACT');
        if k==1
            scanIdx = getStructureAssociatedScan(idx,planC);
            sizV = size(getScanArray(scanIdx,planC));
            mask3M = false(sizV);
        end
        [strMask3M, planC] = getStrMask(idx,planC);
        mask3M = mask3M | strMask3M;
    end

    %Get limits of bbox around union str
    %mask3M = getStrMask(endStr,planC);
    if sum(mask3M(:))>1
        [minr,~,minc,maxc,mins,~] = compute_boundingbox(mask3M);
    else
        minr = 1;
        minc = 1;
        maxc = size(mask3M,2);
        mins = 1;
    end

    %% Get limits of bounding box around cropped pt outline
    outStrName = paramS.structureName.cropStructure;
    idx = getMatchingIndex(outStrName,strC,'EXACT');
    cropMask3M = getStrMask(idx,planC);
    [~,maxr,~,~,~,maxs] = compute_boundingbox(cropMask3M);

    %Get final bounding box
    bbox3M = false(size(mask3M));
    bbox3M(minr:maxr,minc:maxc,mins:maxs) = true;
end

end