function dataS = populate_planC_field(cellName, dcmdir_patient, optS, varargin)
%"populate_planC_field"
%   Given the name of a child cell to planC, such as 'scan', 'dose',
%   'comment', etc. return a copy of that cell with all fields properly
%   populated with data from the files contained in a dcmdir.PATIENT
%   structure.
%
%JRA 06/15/06
%YWU Modified 03/01/08
%NAV 07/19/16 updated to dcm4che3
%   replaced dcm2ml_element with getTagValue
%   and used getValue instead of get
%
%Usage:
%   dataS = populate_planC_field(cellName, dcmdir);
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
% along with CERR.  If not, see <http://www.gnu.org/licenses/>.

%Get template for the requested cell.
persistent rtPlans scanOriS
structS = initializeCERR(cellName);
names   = fieldnames(structS);

dataS = [];
switch cellName
    case 'header'
        rtPlans = []; % Clear persistent object
        for i = 1:length(names)
            dataS.(names{i}) = populate_planC_header_field(names{i}, dcmdir_patient);
        end
        
    case 'scan'
        
        disp('Loading Scan ...')
        
        % supportedModalities = {'CT'};
        scansAdded = 0;
        
        %Extract all series contained in this patient.
        [seriesC, typeC] = extract_all_series(dcmdir_patient);
        % Extract CT, MR, PET, NM... in that order, since frame of
        % reference is reused
        ctIndV = strcmpi(typeC,'CT');
        mrIndV = strcmpi(typeC,'MR');
        newIndV = [];
        newIndV = [newIndV, find(ctIndV), find(mrIndV), find(~(ctIndV | mrIndV))];
        seriesC = seriesC(newIndV);
        typeC = typeC(newIndV);
        
        %ctSeries = length(find(seriesC(strcmpi(typeC, 'CT'))==1));
        
        %Initialize structure to store image orientation per scan.
        scanOriS = struct();
        %Place each series (CT, MR, etc.) into its own array element.
        for seriesNum = 1:length(seriesC)
            % Test IOP here to find if it is "nominal" or "non-nominal"
            % % %             outIOP = getTest_Scan_IOP(seriesC{seriesNum}.Data(1).file);
            if ismember(typeC{seriesNum},{'CT','OT','NM','MR','PT','ST','MG','SM'})
                
                %Populate each field in the scan structure.
                for i = 1:length(names)
                    dataS(scansAdded+1).(names{i}) = ...
                        populate_planC_scan_field(names{i}, ...
                        seriesC{seriesNum}, typeC{seriesNum}, seriesNum, optS);
                end
                
                if isempty(dataS(scansAdded+1).scanInfo(1).rescaleIntercept)
                    dataS(scansAdded+1).scanInfo(1).rescaleIntercept = 0;
                end
                
                %Apply ReScale Intercept and Slope
                scanArray3M = zeros(size(dataS(scansAdded+1).scanArray),'single');
                numSlcs = size(dataS(scansAdded+1).scanArray,3);
                rescaleSlopeV = ones(numSlcs,1);
                realWorldImageFlag = false;
                for slcNum = 1:numSlcs
                    rescaleSlope = dataS(scansAdded+1).scanInfo(slcNum).rescaleSlope;
                    rescaleIntrcpt = dataS(scansAdded+1).scanInfo(slcNum).rescaleIntercept;
                    realWorldValueSlope = dataS(scansAdded+1).scanInfo(slcNum).realWorldValueSlope;
                    realWorldValueIntercept = dataS(scansAdded+1).scanInfo(slcNum).realWorldValueIntercept;
                    realWorldMeasurCodeMeaning = dataS(scansAdded+1).scanInfo(slcNum).realWorldMeasurCodeMeaning;
                    philipsImageUnits = dataS(scansAdded+1).scanInfo(slcNum).philipsImageUnits;
                    philipsRescaleSlope = dataS(scansAdded+1).scanInfo(slcNum).philipsRescaleSlope;
                    philipsRescaleIntercept = dataS(scansAdded+1).scanInfo(slcNum).philipsRescaleIntercept;
                    manufacturer = dataS(scansAdded+1).scanInfo(slcNum).manufacturer;
                    if ~isempty(strfind(lower(manufacturer),'philips')) && ...
                            strcmpi(typeC{seriesNum}, 'MR') && ...
                            ~isempty(realWorldValueSlope) && ...                            
                            ~isempty(philipsImageUnits) && ...
                            ~any(ismember(philipsImageUnits,{'no units','normalized'})) % REAL WORLD VALUE
                        realWorldImageFlag = true;
                        %Apply rescale slope and intercept
                        scanArray3M(:,:,slcNum) = ...
                            single(dataS(scansAdded+1).scanArray(:,:,slcNum)) * single(realWorldValueSlope) + single(realWorldValueIntercept);
                    else % DISPLAY VALUE
                        scanArray3M(:,:,slcNum) = ...
                            single(dataS(scansAdded+1).scanArray(:,:,slcNum)) * single(rescaleSlope) + single(rescaleIntrcpt);                        
                    end
                    rescaleSlopeV(slcNum) = rescaleSlope;
                end

                %Convert to philipsImageUnits
                if realWorldImageFlag
                    idx1  = find(isletter(philipsImageUnits),1);
                    desiredUnits = strtok(philipsImageUnits(idx1:end), '_');
                    desiredScale = str2num(strtok(philipsImageUnits(1:idx1-1), '_'));
                    realWorldMeasurCodeMeaning = char(realWorldMeasurCodeMeaning);
                    idx2  = find(isletter(realWorldMeasurCodeMeaning),1);
                    realWorldUnits = strtok(realWorldMeasurCodeMeaning(idx2:end), '_');
                    if isempty(idx2) || idx2==1
                        realWorldScale = 1;
                    else
                        realWorldScale = str2num(strtok(realWorldMeasurCodeMeaning(1:idx2-1), '_'));
                    end
                    if isempty(realWorldUnits)
                        realWorldUnits = desiredUnits;
                    end
                    if ismember(realWorldUnits,{'mm2/s','mm^2/s'}) && ...
                            ismember(desiredUnits,{'mm2/s','mm^2/s'})
                        correctionFactor = realWorldScale/desiredScale;
                        scanArray3M = scanArray3M .* correctionFactor;
                    else
                        error('philipsImageUnits currently not supported.')
                    end
                end
                minScanVal = min(scanArray3M(:));
                ctOffset = max(0,-minScanVal);
                scanArray3M = scanArray3M + ctOffset;
                minScanVal = min(scanArray3M(:));
                maxScanVal = max(scanArray3M(:));                
                if ~realWorldImageFlag && ~any(abs(rescaleSlopeV-1) > eps*1e5) % convert to uint if rescale slope is not 1.
                   if minScanVal >= -32768 && maxScanVal <= 32767
                       scanArray3M = uint16(scanArray3M);
                   else
                       scanArray3M = uint32(scanArray3M);
                   end
                end
                for slcNum = 1:numSlcs
                    dataS(scansAdded+1).scanInfo(slcNum).CTOffset = ctOffset;
                end
                dataS(scansAdded+1).scanArray = scanArray3M;
                
                %Apply scale slope & intercept for Philips data if not
                %realWorldValue
                if strcmpi(typeC{seriesNum}, 'MR') && ...
                        strcmpi(optS.store_scan_as_mr_philips_precise_value, 'yes')
                    % Ref: Chenevert, Thomas L., et al. "Errors in quantitative image analysis due to platform-dependent image scaling."
                    manufacturer = dataS(scansAdded+1).scanInfo(1).manufacturer;
                    if ~isempty(strfind(lower(manufacturer),'philips')) && ...
                            ~isempty(dataS(scansAdded+1).scanInfo(1).scaleSlope) && ...
                            ~realWorldImageFlag
                        scaleSlope = dataS(scansAdded+1).scanInfo(1).scaleSlope;
                        dataS(scansAdded+1).scanArray = single(dataS(scansAdded+1).scanArray)./(rescaleSlope*scaleSlope);
                    end
                end
                
                scansAdded = scansAdded + 1;
                
            elseif strcmpi(typeC{seriesNum}, 'US')
                %Populate each field in the scan structure.
                for i = 1:length(names)
                    dataS(scansAdded+1).(names{i}) = populate_planC_USscan_field(names{i}, seriesC{seriesNum}, typeC{seriesNum});
                end
                scansAdded = scansAdded + 1;
            end
            scanOriS(scansAdded).scanUID = dataS(scansAdded).scanUID;
            scanOriS(scansAdded).imageOrientationPatient = dataS(scansAdded).scanInfo(1).imageOrientationPatient;
        end
        
                
    case 'structures'
        [seriesC, typeC]    = extract_all_series(dcmdir_patient);
        structsAdded          = 0;
        
        % Get scan object from varargin if it is not empty.
        % for inserting structures to existing planC
        if ~isempty(varargin)
            scanOriS = varargin{1};
        end
        
        %hWaitbar = waitbar(0,'Loading Structures Please wait...');
        
        %strSeries = length(find(strcmpi(typeC, 'RTSTRUCT')==1));
        
        disp('Loading RTSTRUCT ...')
        
        %Place each structure into its own array element.
        for seriesNum = 1:length(seriesC)
            %if ismember(typeC{seriesNum}, supportedTypes)
            if strcmpi(typeC{seriesNum}, 'RTSTRUCT')
                
                RTSTRUCT = seriesC{seriesNum}.Data;
                for k = 1:length(RTSTRUCT)
                    strobj  = scanfile_mldcm(RTSTRUCT(k).file);
                    
                    % StructureSetROISequence
                    SSRS = strobj.getValue(805699616); %org.dcm4che3.data.Tag.StructureSetROISequence; %hex2dec('30060020')
                    numSSRS = SSRS.size();
                    roiNummV = zeros(1,numSSRS,'int32');
                    for iStr = 1:numSSRS
                        ssObj = SSRS.get(iStr - 1);
                        roiNummV(iStr) = ssObj.getInts(805699618); %org.dcm4che3.data.Tag.ROINumber; % vr=IS
                    end
                    
                    %ROI Contour Sequence.
                    RCS = strobj.getValue(805699641); %org.dcm4che3.data.Tag.ROIContourSequence; % hex2dec('30060039')
                    
                    %If non-empty sequence, get item count, else set to zero
                    if ~isempty(RCS)
                        nStructures = RCS.size();
                    else
                        nStructures = 0;
                    end
                    
                    % ROI = strobj.getInt(org.dcm4che2.data.Tag.ROIContourSequence);
                    
                    structuresToImportC = optS.structuresToImport;
                    
                    structuresImportMatchCriteria = optS.structuresImportMatchCriteria;
                    
                    %curStructNum = 1; %wy modified for suppport multiple RS files
                    for structNum = 1:nStructures
                        
                        cObj = RCS.get(structNum - 1);
                        
                        %Referenced ROI Number
                        %RRN = getTagValue(cObj, '30060084');
                        RRN = cObj.getInts(805699716); %org.dcm4che3.data.Tag.ReferencedROINumber; %IS
                        
                        indSSRS = find(ismember(roiNummV,RRN));
                        
                        % Get Structure name
                        ssObj = SSRS.get(indSSRS - 1);
                        %structureName = getTagValue(ssObj, '30060026');
                        structureName = char(ssObj.getStrings(805699622)); %org.dcm4che3.data.Tag.ROIName;
                        
                        if ~isempty(structuresToImportC)
                            matchIndex = getMatchingIndex(structureName,...
                                structuresToImportC,...
                                structuresImportMatchCriteria);
                        else
                            matchIndex = 1;
                        end
                        
                        if isempty(matchIndex)
                            continue;
                        end
                        
                        %Populate each field in the structure field set
                        for i = 1:length(names)
                            dataS(structsAdded+1).(names{i}) = ...
                                populate_planC_structures_field(names{i}, ...
                                RTSTRUCT, scanOriS, strobj, ssObj, cObj, optS);
                        end
                        %curStructNum = curStructNum + 1;
                        structsAdded = structsAdded + 1;
                        
                        %waitbar(structsAdded/(nStructures*length(RTSTRUCT)*strSeries), hWaitbar, 'Loading structures, Please wait...');
                        
                        %a temporary limit of 52 structs
                        %if (structsAdded>=52)
                        %    return;
                        %end
                        
                    end
                end
                
            end
            
        end
        %close(hWaitbar);
        %pause(0.1);
        
        %     case 'structureArray'
        %         populate_planC_structureArray_field(fieldName, dcmdir);
        
    case 'dose'
        [seriesC, typeC]    = extract_all_series(dcmdir_patient);
        dosesAdded          = 0;
        frameOfRefUIDC       = {};
        %Place each RTDOSE into its own array element.
        for seriesNum = 1:length(seriesC)
            %             if ismember(typeC{seriesNum}, supportedTypes)
            if strcmpi(typeC{seriesNum}, 'RTDOSE')
                
                RTDOSE = seriesC{seriesNum}.Data; %wy RTDOSE{1} for import more than one dose files;
                for doseNum = 1:length(RTDOSE)
                    doseobj  = scanfile_mldcm(RTDOSE(doseNum).file);
                    
                    % Frame of Reference UID
                    %frameOfRefUID = getTagValue(doseobj, '00200052');
                    frameOfRefUID = char(doseobj.getStrings(2097234)); %org.dcm4che3.data.Tag.FrameOfReferenceUID;
                    
                    %check if it is a DVH
                    dvhsequence = populate_planC_dose_field('dvhsequence', ...
                        RTDOSE(doseNum), doseobj, rtPlans, optS);
                    
                    %Check if doesArray is present
                    dose3M = populate_planC_dose_field('doseArray', ...
                        RTDOSE(doseNum), doseobj, rtPlans, optS);
                    
                    if isempty(dvhsequence) || ~isempty(dose3M)
                        %Populate each field in the dose structure.
                        for i = 1:length(names)
                            dataSeriesS(doseNum).(names{i}) = ...
                                populate_planC_dose_field(names{i}, ...
                                RTDOSE(doseNum), doseobj, rtPlans, optS);
                        end
                        
                        if isempty(frameOfRefUIDC)
                            frameOfRefUIDC{1} = frameOfRefUID;
                        else
                            frameOfRefUIDC{end+1} = frameOfRefUID;
                        end
                        
                        % Check if frame of reference UID matches any
                        % existing doses and add slices.
                        
                        % If frame of reference UID does not match, then
                        % create a new dose
                        %dosesAdded = dosesAdded + 1;
                    end
                end
                
                multiFrameC = cellfun(@(x) x > 1,{dataSeriesS.numberMultiFrameImages},'UniformOutput',false);
                multiFrameIndV = [];
                for iM = 1:length(multiFrameC)
                    if isempty(multiFrameC{iM}) || (~isempty(multiFrameC{iM}) && multiFrameC{iM}==0)
                        multiFrameIndV(iM) = 0;
                    else
                        multiFrameIndV(iM) = 1;
                    end
                end
                multiFrameDoseNumsV = find(multiFrameIndV);
                for doseNum = multiFrameDoseNumsV
                    dosesAdded = dosesAdded + 1;
                    if isempty(dataS)
                        dataS = dataSeriesS(doseNum);
                    else
                        dataS(dosesAdded) = dataSeriesS(doseNum);
                    end
                end
                
                singleFrameIndV = ~multiFrameIndV;
                dataSeriesS = dataSeriesS(singleFrameIndV);
                doseSummationTypes = unique({dataSeriesS.doseSummationType});
                for doseTypeNum = 1:length(doseSummationTypes)
                    doseSumType = doseSummationTypes{doseTypeNum};
                    indV = strcmpi(doseSumType,{dataSeriesS.doseSummationType});
                    doseSeries = dataSeriesS(indV);
                    switch doseSumType
                        case 'BEAM'
                            beamNumberV = unique([doseSeries.refBeamNumber]);
                            for iB = 1:length(beamNumberV)
                                beamNum = beamNumberV(iB);
                                indV = [doseSeries.refBeamNumber] == beamNum;
                                doseS = doseSeries(indV);
                                [dataS,dosesAdded] = addDoseToSeries(doseS,dataS,dosesAdded);
                            end
                        case 'FRACTION'
                            fractionNumberV = unique(doseSeries.refFractionGroupNumber);
                            for iF = 1:length(fractionNumberV)
                                fractionNumber = fractionNumberV(iF);
                                indV = [doseSeries.refFractionGroupNumber] == fractionNumber;
                                doseS = doseSeries(indV);
                                [dataS,dosesAdded] = addDoseToSeries(doseS,dataS,dosesAdded);
                            end
                        otherwise
                            doseS = doseSeries;
                            [dataS,dosesAdded] = addDoseToSeries(doseS,dataS,dosesAdded);
                            
                    end
                    
                end
                
            end
            
        end
        
        % Get doses that have same frame of reference UIDs
        %[uniqFrameOfRefUIDC,jnk,uniqIndV] = unique(frameOfRefUIDC);
        %dataS(find(uniqIndV==1))
        
        
    case 'DVH'
        [seriesC, typeC]    = extract_all_series(dcmdir_patient);
        supportedTypes      = {'DVH'};
        dvhsAdded           = 0;
        
        %Place each RTDOSE into its own array element.
        for seriesNum = 1:length(seriesC)
            
            %             if ismember(typeC{seriesNum}, supportedTypes)
            if strcmpi(typeC{seriesNum}, 'RTDOSE')
                
                RTDOSE = seriesC{seriesNum}.Data; %wy RTDOSE{1} for import more than one dose files;
                for doseNum = 1:length(RTDOSE)
                    doseobj  = scanfile_mldcm(RTDOSE(doseNum).file);
                    
                    %check if it is a DVH
                    dvhsequence = populate_planC_dose_field('dvhsequence', ...
                        RTDOSE(doseNum), doseobj, rtPlans, optS);
                    
                    if ~isempty(dvhsequence) && ~dvhsequence.isEmpty
                        
                        structureNameC = {};
                        structureNumberV = [];
                        
                        % get a list of Structure Names
                        for seriesNumStr = 1:length(seriesC)
                            
                            if strcmpi(typeC{seriesNumStr}, 'RTSTRUCT')
                                
                                RTSTRUCT = seriesC{seriesNumStr}.Data;
                                for k = 1:length(RTSTRUCT)
                                    strobj  = scanfile_mldcm(RTSTRUCT(k).file);
                                    
                                    % StructureSetROISequence
                                    SSRS = strobj.getValue(805699616); %org.dcm4che3.data.Tag.StructureSetROISequence; %hex2dec('30060020');
                                    numSSRS = SSRS.size();
                                    for js = 1:numSSRS
                                        % Get Structure name
                                        ssObj = SSRS.get(js - 1);
                                        
                                        %structureName = getTagValue(ssObj, '30060026');
                                        structureNameC{end+1} = char(ssObj.getStrings(805699622)); %org.dcm4che3.data.Tag.ROIName;
                                        structureNumberV(end+1) = ssObj.getInts(805699618); %org.dcm4che3.data.Tag.ROINumber;
                                        
                                    end
                                end
                                
                            end
                            
                        end
                        
                        %DVH_items = fieldnames(dvhsequence);
                        DVH_items = dvhsequence.size();
                        for i = 1:DVH_items
                            dvhsAdded = dvhsAdded + 1;
                            for j = 1:length(names)
                                dataS(dvhsAdded).(names{j}) = populate_planC_DVH_field(names{j}, RTDOSE(doseNum), doseobj, rtPlans);
                            end
                            dvhObj = dvhsequence.get(i-1);
                            dataS(dvhsAdded).volumeType = char(dvhObj.getStrings(805568513)); %org.dcm4che3.data.Tag.DVHType;
                            dataS(dvhsAdded).doseType = char(dvhObj.getStrings(805568516)); %org.dcm4che3.data.Tag.DoseType;
                            dataS(dvhsAdded).doseUnits = char(dvhObj.getStrings(805568514)); %org.dcm4che3.data.Tag.DoseUnits;
                            
                            %dataS(dvhsAdded+1).volumeType = dvhsequence.(['Item_',num2str(i)]).DVHType;
                            %dataS(dvhsAdded+1).doseType = dvhsequence.(['Item_',num2str(i)]).DoseType;
                            %dataS(dvhsAdded+1).doseUnits = dvhsequence.(['Item_',num2str(i)]).DoseUnits;
                            
                            dvhReferencedROISequence = dvhObj.getValue(805568608); %org.dcm4che3.data.Tag.DVHReferencedROISequence;
                            if ~isempty(dvhReferencedROISequence) %isfield(dvhsequence.(['Item_',num2str(i)]),'DVHReferencedROISequence')
                                %structureNumber = dvhsequence.(['Item_',num2str(i)]).DVHReferencedROISequence.Item_1.ReferencedROINumber;
                                structureNumber = dvhReferencedROISequence.get(0).getInts(805699716); %org.dcm4che3.data.Tag.ReferencedROINumber); % .(['Item_',num2str(i)]).DVHReferencedROISequence.Item_1.ReferencedROINumber;
                                indROINumber = find(structureNumberV==structureNumber);
                                if ~isempty(indROINumber)
                                    %dataS(dvhsAdded+1).structureName = structureNameC{indROINumber};
                                    dataS(dvhsAdded).structureName = structureNameC{indROINumber};
                                end
                            end
                            %dataS(dvhsAdded+1).doseScale = dvhsequence.(['Item_',num2str(i)]).DVHDoseScaling;
                            dataS(dvhsAdded).doseScale = dvhObj.getDoubles(805568594); %org.dcm4che3.data.Tag.DVHDoseScaling;
                            %binWidthsV = dvhsequence.(['Item_',num2str(i)]).DVHData(1:2:end);
                            binWidthsV = dvhObj.getDoubles(805568600); %org.dcm4che3.data.Tag.DVHData;
                            binWidthsV = binWidthsV(1:2:end);
                            volumeBinsV = dvhObj.getDoubles(805568600); %org.dcm4che3.data.Tag.DVHData;
                            volumeBinsV = volumeBinsV(2:2:end);
                            
                            %maxDVHDose = dvhsequence.(['Item_',num2str(i)]).DVHMaximumDose;
                            %minDVHDose = dvhsequence.(['Item_',num2str(i)]).DVHMinimumDose;
                            doseBinsV = [];
                            doseBinsV(1) = 0;
                            for iBin = 2:length(binWidthsV)
                                doseBinsV(iBin) = doseBinsV(iBin-1) + binWidthsV(iBin);
                            end
                            dataS(dvhsAdded).DVHMatrix(:,1) = doseBinsV(:);
                            if strcmpi(dataS(dvhsAdded).volumeType,'cumulative')
                                if length(doseBinsV) > 1
                                    %volumeBinsV = dvhsequence.(['Item_',num2str(i)]).DVHData(2:2:end);
                                    volumeBinsV = diff(volumeBinsV(1)-volumeBinsV);
                                    volumeBinsV = [volumeBinsV(1); volumeBinsV(:)];
                                else
                                    volumeBinsV = dataS(dvhsAdded).DVHMatrix(:,1)*NaN;
                                end
                            else
                                %volumeBinsV = dvhsequence.(['Item_',num2str(i)]).DVHData(2:2:end);
                                volumeBinsV = volumeBinsV(:);
                            end
                            dataS(dvhsAdded).DVHMatrix(:,2) = volumeBinsV;
                            %dvhsAdded = dvhsAdded + 1;
                        end
                        
                    end
                end
            end
            
        end
        
        
        %     case 'digitalFilm'
        %         populate_planC_digitalFilm_field(fieldName, dcmdir);
        %     case 'RTTreatment'
        %         populate_planC_RTTreatment_field(fieldName, dcmdir);
        %     case 'IM'
        %         populate_planC_IM_field(fieldName, dcmdir);
        
    case 'beams'
        [seriesC, typeC] = extract_all_series(dcmdir_patient);
        %%%DK Re-writing RTPLAN file to not use MATLAB image processing
        %%%tool.
        
        seriesNum = find(strncmpi('RTPLAN', typeC, 6));
        
        planCount = 0;
        
        for j = 1:length(seriesNum)
            RTPLAN = seriesC{seriesNum(j)}.Data;
            
            for planNum = 1:length(RTPLAN)
                
                planCount = planCount + 1;
                
                planobj  = scanfile_mldcm(RTPLAN(planNum).file);
                
                %Populate each field in the dose structure.
                for i = 1:length(names)
                    dataS(planCount).(names{i}) = populate_planC_beams_field(names{i}, RTPLAN(planNum), planobj);
                end
                
            end
            
        end
        rtPlans= dataS;
        
    case 'beamGeometry'
        
        dataS = initializeCERR('beamGeometry');
        
        for i = 1:length(rtPlans)
            beamGeometryS = populate_planC_beamGeometry_field(rtPlans(i), dataS);
            
            for j = 1:length(beamGeometryS)
                dataS = dissimilarInsert(dataS, beamGeometryS(j), length(dataS)+1);
            end
        end
        
        %%%OLD RTPLAN import code. commented DK?
        % %         %Place RTPLAN into planC{indexS.beams}
        % %         plansAdded = 0;
        % %         for seriesNum = 1:length(seriesC)
        % %             RTPLAN = seriesC{seriesNum}.Data;
        % %             for planNum =  1:length(RTPLAN)
        % %
        % %                 if strcmpi(typeC{seriesNum}, 'RTPLAN')
        % %
        % %                     try
        % %                         if plansAdded == 0m
        % %                             dataS =
        % dicominfo(seriesC{seriesNum}.Data(planNum).file);
        % %                         else
        % %                             dataS(plansAdded + 1) = dicominfo(seriesC{seriesNum}.Data(planNum).file);
        % %                         end
        % %                         plansAdded = plansAdded + 1;
        % %                         warning('Matlab''s Image Processing Toolbox was used to read RTPLAN...')
        % %                     catch
        % %                         warning('Matlab''s Image Processing Toolbox is required to read RTPLAN. Ignoring...')
        % %                     end
        % %
        % %                 end
        % %
        % %             end
        % %         end
        
        
    case 'GSPS'
        [seriesC, typeC]    = extract_all_series(dcmdir_patient);
        supportedTypes      = {'PR'};
        gspsAdded          = 0;
        
        %hWaitbar = waitbar(0,'Loading GSPS. Please wait...');
        
        numGspsSeries = length(find(strcmpi(typeC, 'PR')==1));
        
        %Place each structure into its own array element.
        for seriesNum = 1:length(seriesC)
            
            %if ismember(typeC{seriesNum}, supportedTypes)
            if strcmpi(typeC{seriesNum}, 'PR')
                GSPS = seriesC{seriesNum}.Data;
                for k = 1:length(GSPS)
                    gspsobj  = scanfile_mldcm(GSPS(k).file);
                    
                    %Graphic Annotation Sequence.
                    el = gspsobj.getValue(7340033); %org.dcm4che3.data.Tag.GraphicAnnotationSequence; %hex2dec('00700001')
                    
                    % ROI = strobj.getInt(org.dcm4che2.data.Tag.ROIContourSequence);
                    
                    if ~isempty(el)
                        nGsps = el.size();
                    else
                        nGsps = 0;
                    end
                    curGspsNum = 1;
                    for j = 1:nGsps
                        
                        %Populate each field in the structure field set
                        for i = 1:length(names)
                            dataS(gspsAdded+1).(names{i}) = populate_planC_gsps_field(names{i}, GSPS, curGspsNum, gspsobj);
                        end
                        curGspsNum = curGspsNum + 1;
                        gspsAdded = gspsAdded + 1;
                        
                        %waitbar(gspsAdded/(nGsps*length(GSPS)*numGspsSeries), hWaitbar, 'Loading Annotations, Please wait...');
                        
                    end
                end
            end
            
        end
        %close(hWaitbar);
        pause(0.1);
        
    case 'registration'
        [seriesC, typeC]    = extract_all_series(dcmdir_patient);
        supportedTypes      = {'REG'};
        registrationsAdded  = 0;
        frameOfRefUIDC      = {};
        %Place each REG into its own array element.
        for seriesNum = 1:length(seriesC)
            
            %             if ismember(typeC{seriesNum}, supportedTypes)
            if strcmpi(typeC{seriesNum}, 'REG')
                
                REG = seriesC{seriesNum}.Data; %wy RTDOSE{1} for import more than one dose files;
                for regNum = 1:length(REG)
                    regobj  = scanfile_mldcm(REG(regNum).file);
                    
                    % Frame of Reference UID
                    %frameOfRefUID = getTagValue(regobj, '00200052');
                    frameOfRefUID = char(regobj.getStrings(2097234)); %org.dcm4che3.data.Tag.FrameOfReferenceUID;
                    
                    
                    %Populate each field in the dose structure.
                    for i = 1:length(names)
                        dataS(registrationsAdded+1).(names{i}) = populate_planC_registration_field(names{i}, REG(regNum), regobj);
                    end
                    
                    if isempty(frameOfRefUIDC)
                        frameOfRefUIDC{1} = frameOfRefUID;
                    else
                        frameOfRefUIDC{end+1} = frameOfRefUID;
                    end
                    
                    % Check if frame of reference UID matches any
                    % existing doses and add slices.
                    
                    % If frame of reference UID does not match, then
                    % create a new dose
                    registrationsAdded = registrationsAdded + 1;
                end
            end
            
        end
        
        
    case 'importLog'
        %Implementation is unnecessary.
        
    case 'CERROptions'
        pathStr = getCERRPath;
        optName = [pathStr 'CERROptions.json'];
        dataS = opts4Exe(optName);
        
    case 'indexS'
        %Implementation is unnecessary.
        
    otherwise
        % disp(['DICOM Import has no methods defined for import into the planC{indexS.' cellName '} structure, leaving empty.']);
end

end

function [dataS,dosesAdded] = addDoseToSeries(doseS,dataS,dosesAdded)
if length(doseS) > 1
    doseArray = [];
    zValues = [];
    for slcNum = 1:length(doseS)
        doseArray(:,:,slcNum) = doseS(slcNum).doseArray;
        zValues(slcNum) = doseS(slcNum).zValues;
    end
    % Sort doseArray as per zValues
    [zValues,indSort] = sort(zValues);
    doseArray(:,:,1:end) = doseArray(:,:,indSort);
    doseS(1).doseArray = doseArray;
    doseS(1).zValues = zValues;
end
dosesAdded = dosesAdded + 1;

if isempty(dataS)
    dataS = doseS(1);
else
    dataS(dosesAdded) = doseS(1);
end

end

