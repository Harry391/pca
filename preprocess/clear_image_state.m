function state = clear_image_state(state)
%CLEAR_IMAGE_STATE Reset image-related fields.

    state.currentImage = [];
    state.currentImagePath = "";
    state.currentPreprocessBaseImage = [];
    state.currentPreprocessBaseLabel = "";
    state.currentRestoreImage = [];
    state.currentRestoreLabel = "";
    state.currentGrayImage = [];
    state.currentProcessedImage = [];
    state.currentFaceBox = [];
    state.currentFaceInfo = struct();
    state.currentFaceRoi = [];
    state.currentFaceRoiListeners = [];
    state.currentAlignInfo = struct();
    state.currentAlignedFace = [];
    state.currentCameraFrame = [];
end

