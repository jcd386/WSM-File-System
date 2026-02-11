import { LightningElement, api } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getFolderContents from "@salesforce/apex/WSMFolderTreeService.getFolderContents";
import getParentFolderInfo from "@salesforce/apex/WSMFolderTreeService.getParentFolderInfo";
import getFolderParentInfo from "@salesforce/apex/WSMFolderTreeService.getFolderParentInfo";
import getFoldersForSelect from "@salesforce/apex/WSMFolderTreeService.getFoldersForSelect";
import createFileRecord from "@salesforce/apex/WSMFolderTreeService.createFileRecord";
import createFolder from "@salesforce/apex/WSMFolderTreeService.createFolder";
import moveFile from "@salesforce/apex/WSMFolderTreeService.moveFile";
import deleteFile from "@salesforce/apex/WSMFolderTreeService.deleteFile";
import getAllAccountRootFolders from "@salesforce/apex/WSMFolderTreeService.getAllAccountRootFolders";
import searchFolders from "@salesforce/apex/WSMFolderTreeService.searchFolders";
import uploadFileFromBase64 from "@salesforce/apex/WSMFolderTreeService.uploadFileFromBase64";
import renameFolder from "@salesforce/apex/WSMFolderTreeService.renameFolder";
import deleteFolder from "@salesforce/apex/WSMFolderTreeService.deleteFolder";
import moveFolder from "@salesforce/apex/WSMFolderTreeService.moveFolder";
import getFolderContentsCount from "@salesforce/apex/WSMFolderTreeService.getFolderContentsCount";

// Maximum file size for drag-drop upload (4.5MB to stay within Apex heap limits)
const MAX_FILE_SIZE_BYTES = 4718592;

// File extension → SLDS doctype icon mapping
const FILE_ICON_MAP = {
  pdf: 'doctype:pdf',
  csv: 'doctype:csv',
  xls: 'doctype:excel',
  xlsx: 'doctype:excel',
  doc: 'doctype:word',
  docx: 'doctype:word',
  ppt: 'doctype:ppt',
  pptx: 'doctype:ppt',
  jpg: 'doctype:image',
  jpeg: 'doctype:image',
  png: 'doctype:image',
  gif: 'doctype:image',
  bmp: 'doctype:image',
  webp: 'doctype:image',
  txt: 'doctype:txt',
  rtf: 'doctype:rtf',
  zip: 'doctype:zip'
};
const DEFAULT_FILE_ICON = 'doctype:unknown';
const FOLDER_ICON = 'utility:open_folder';

// Allowed file extensions for drag-drop validation
const ALLOWED_EXTENSIONS = new Set([
  'pdf', 'csv',
  'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp',
  'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx',
  'txt', 'rtf', 'zip'
]);

export default class WsmFolderTreeV2 extends NavigationMixin(LightningElement) {
  @api recordId;

  // Track previous recordId to detect changes
  _previousRecordId;

  currentFolderContents = [];
  currentFolderId = null;
  breadcrumbs = [];
  error;
  isLoading = false;
  parentFolderInfo = null;
  showGoUpButton = false;

  // Upload modal state
  showUploadModal = false;
  folderOptions = [];
  selectedUploadFolderId = null;
  isUploading = false;
  uploadError = null;
  uploadSuccess = null;
  pendingUploads = [];

  // New Folder modal state
  showNewFolderModal = false;
  newFolderName = '';
  newFolderError = null;
  newFolderSuccess = null;
  isCreatingFolder = false;

  // Move File modal state
  showMoveFileModal = false;
  fileToMoveId = null;
  fileToMoveName = '';
  moveFileError = null;
  isMovingFile = false;
  isLoadingModalFolders = false;
  fileWasMovedSuccessfully = false;

  // Delete File modal state
  showDeleteFileModal = false;
  fileToDeleteId = null;
  fileToDeleteName = '';
  deleteFileError = null;
  isDeletingFile = false;
  fileWasDeletedSuccessfully = false;

  // Modal navigation state
  modalCurrentFolderId = null;
  modalCurrentRecordId = null;
  modalFolderContents = [];
  modalBreadcrumbs = [];
  showAllAccountsView = false;
  accountFolderGroups = [];

  // Modal search state
  modalSearchTerm = '';
  modalSearchResults = [];
  showSearchResults = false;

  // ─────────────────────────────────────────────────────────────────────────
  // DRAG AND DROP STATE (V2 FEATURE)
  // ─────────────────────────────────────────────────────────────────────────
  isDragOver = false;
  isUploadingDroppedFiles = false;
  droppedFileUploadStatus = null;
  _dragCounter = 0; // Track drag enter/leave for nested elements

  // ─────────────────────────────────────────────────────────────────────────
  // FOLDER OPERATIONS STATE
  // ─────────────────────────────────────────────────────────────────────────

  // Rename Folder modal state
  showRenameFolderModal = false;
  folderToRenameId = null;
  folderToRenameName = '';
  newFolderNameInput = '';
  renameFolderError = null;
  isRenamingFolder = false;

  // Delete Folder modal state
  showDeleteFolderModal = false;
  folderToDeleteId = null;
  folderToDeleteName = '';
  deleteFolderError = null;
  isDeletingFolder = false;
  folderContentsCount = null;

  // Move Folder modal state
  showMoveFolderModal = false;
  folderToMoveId = null;
  folderToMoveName = '';
  moveFolderError = null;
  isMovingFolder = false;
  isLoadingMoveFolderFolders = false;
  moveFolderCurrentFolderId = null;
  moveFolderCurrentRecordId = null;
  moveFolderContents = [];
  moveFolderBreadcrumbs = [];
  showMoveFolderAllAccountsView = false;
  moveFolderAccountFolderGroups = [];

  connectedCallback() {
    if (this.recordId) {
      this._previousRecordId = this.recordId;
      this.initializeComponent();
    } else {
      this.error = 'No record ID provided. Please place this component on a record page.';
    }
  }

  renderedCallback() {
    // Reset component if recordId changes (e.g., navigating to different record)
    if (this.recordId && this.recordId !== this._previousRecordId) {
      this._previousRecordId = this.recordId;
      this.resetToRoot();
    }
  }

  resetToRoot() {
    this.currentFolderId = null;
    this.breadcrumbs = [];
    this.currentFolderContents = [];
    this.error = undefined;
    this.initializeComponent();
  }

  async initializeComponent() {
    try {
      // Check if this record has a parent folder (cross-record navigation)
      await this.checkForParentFolder();

      // Load root folders first
      await this.loadFolderContents();

      // Automatically navigate into the first root folder to have it open by default
      const firstRootFolder = this.currentFolderContents.find(
        item => item.nodeType === 'Folder'
      );

      if (firstRootFolder) {
        this.navigateToFolder(firstRootFolder.recordId, firstRootFolder.label);
      }
    } catch (err) {
      console.error('Error initializing folder tree:', err);
    }
  }

  async checkForParentFolder() {
    try {
      // If we're currently in a folder, check if THAT folder has a parent
      if (this.currentFolderId) {
        const folderParent = await getFolderParentInfo({ folderId: this.currentFolderId });
        if (folderParent && folderParent.parentFolderId) {
          this.parentFolderInfo = folderParent;
          this.showGoUpButton = true;
          return;
        }
      }

      // Otherwise, check if this record's folders are nested under a parent record
      const data = await getParentFolderInfo({ parentRecordId: this.recordId });
      if (data && data.parentFolderId) {
        this.parentFolderInfo = data;
        this.showGoUpButton = true;
      } else {
        this.parentFolderInfo = null;
        this.showGoUpButton = false;
      }
    } catch (error) {
      console.error('Error checking for parent folder:', error);
      this.parentFolderInfo = null;
      this.showGoUpButton = false;
    }
  }

  async handleGoUp() {
    if (!this.parentFolderInfo) return;

    // Check if we're switching records (cross-record navigation)
    const switchingRecords = this.parentFolderInfo.parentRecordId !== this.recordId;

    if (switchingRecords) {
      // Navigate to parent record's context
      this.recordId = this.parentFolderInfo.parentRecordId;
      this._previousRecordId = this.recordId;
      this.breadcrumbs = [];
    }

    // Navigate to the parent folder
    this.currentFolderId = this.parentFolderInfo.parentFolderId;
    this.breadcrumbs = [{
      id: this.parentFolderInfo.parentFolderId,
      label: this.parentFolderInfo.parentFolderName
    }];

    // Check if the new position has a parent
    await this.checkForParentFolder();

    // Load the parent folder's contents
    await this.loadFolderContents();
  }

  async loadFolderContents() {
    if (!this.recordId) {
      this.error = 'No record ID provided.';
      return;
    }

    this.isLoading = true;
    this.error = undefined;

    try {
      const data = await getFolderContents({
        parentRecordId: this.recordId,
        currentFolderId: this.currentFolderId
      });

      if (!data) {
        this.currentFolderContents = [];
        return;
      }

      // Add isFolder, isFile properties, fileUrl, contentDocumentId, and aria-label for template conditionals and accessibility
      const mappedData = data
        .filter(item => item && item.key)
        .map(item => ({
          ...item,
          isFolder: item.nodeType === 'Folder',
          isFile: item.nodeType === 'File',
          fileUrl: item.fileUrl || null,
          contentDocumentId: item.contentDocumentId || null,
          filePreviewUrl: null, // Will be populated below
          iconName: item.nodeType === 'Folder' ? FOLDER_ICON : this.getFileIcon(item.label),
          iconAlternativeText: item.nodeType === 'Folder'
            ? 'Folder'
            : (this.getFileExtension(item.label)?.toUpperCase() || 'File') + ' file',
          folderAriaLabel: item.nodeType === 'Folder' ? `Open folder ${item.label}` : null,
          formattedCreatedDate: this.formatDate(item.createdDate),
          createdBy: item.createdBy || '',
          menuAlternativeText: `Actions for ${item.label}`
        }));

      // Generate file preview URLs for items with contentDocumentId
      await this.generateFilePreviewUrls(mappedData);

      this.currentFolderContents = mappedData;

    } catch (error) {
      this.currentFolderContents = [];
      this.error = this.normalizeError(error);
    } finally {
      this.isLoading = false;
    }
  }

  handleFolderClick(event) {
    event.preventDefault();
    const folderId = event.currentTarget.dataset.folderId;
    const folderName = event.currentTarget.dataset.folderName;
    if (folderId && folderName) {
      this.navigateToFolder(folderId, folderName);
    }
  }

  handleFileClick(event) {
    event.preventDefault();
    const contentDocId = event.currentTarget.dataset.contentDocumentId;
    if (contentDocId) {
      // Open file preview modal
      this[NavigationMixin.Navigate]({
        type: "standard__namedPage",
        attributes: { pageName: "filePreview" },
        state: {
          selectedRecordId: contentDocId,
          recordIds: contentDocId
        }
      });
    }
  }

  /**
   * Handles View File click - opens native Salesforce file preview modal
   * @param {Event} event - Click event
   */
  handleViewFile(event) {
    event.preventDefault();
    const contentDocId = event.currentTarget.dataset.contentDocumentId;
    if (contentDocId) {
      this[NavigationMixin.Navigate]({
        type: "standard__namedPage",
        attributes: {
          pageName: "filePreview"
        },
        state: {
          selectedRecordId: contentDocId,
          recordIds: contentDocId
        }
      });
    }
  }

  /**
   * Generates file preview URLs for items with contentDocumentId
   * @param {Array} items - Array of mapped folder content items
   */
  async generateFilePreviewUrls(items) {
    const promises = items
      .filter(item => item.contentDocumentId)
      .map(async (item) => {
        try {
          const url = await this[NavigationMixin.GenerateUrl]({
            type: "standard__namedPage",
            attributes: {
              pageName: "filePreview"
            },
            state: {
              selectedRecordId: item.contentDocumentId,
              recordIds: item.contentDocumentId
            }
          });
          item.filePreviewUrl = url;
        } catch (err) {
          console.error('Error generating preview URL for', item.label, err);
          item.filePreviewUrl = null;
        }
      });

    await Promise.all(promises);
  }

  navigateToFolder(folderId, folderName) {
    if (!folderId || !folderName) {
      return;
    }

    // Prevent duplicate breadcrumbs
    if (this.breadcrumbs.some(crumb => crumb.id === folderId)) {
      return;
    }

    this.currentFolderId = folderId;
    this.breadcrumbs = [...this.breadcrumbs, { id: folderId, label: folderName }];
    this.loadFolderContents();
  }

  handleBreadcrumbClick(event) {
    event.preventDefault();
    const targetId = event.currentTarget.dataset.breadcrumbId;

    // Find the index of the clicked breadcrumb
    const index = this.breadcrumbs.findIndex((b) => b.id === targetId);
    if (index === -1) return;

    // Remove all breadcrumbs after the clicked one
    this.breadcrumbs = this.breadcrumbs.slice(0, index + 1);

    // Set current folder to the clicked breadcrumb (or null if no breadcrumbs remain)
    this.currentFolderId = this.breadcrumbs.length > 0
      ? this.breadcrumbs[this.breadcrumbs.length - 1].id
      : null;

    this.loadFolderContents();
  }

  get hasContents() {
    return this.currentFolderContents && this.currentFolderContents.length > 0;
  }

  get breadcrumbsWithLast() {
    return this.breadcrumbs.map((crumb, index) => ({
      ...crumb,
      isLast: index === this.breadcrumbs.length - 1
    }));
  }

  normalizeError(err) {
    if (!err) return "Unknown error";
    const body = err.body;
    if (Array.isArray(body)) return body.map((e) => e.message).join("; ");
    return body?.message || err.message || JSON.stringify(err);
  }

  /**
   * Formats a datetime value for display
   * @param {string|Date} dateValue - The datetime value to format
   * @returns {string} Formatted date string (MM/DD/YYYY) or empty string
   */
  formatDate(dateValue) {
    if (!dateValue) return '';
    try {
      const date = new Date(dateValue);
      if (isNaN(date.getTime())) return '';
      const month = String(date.getMonth() + 1).padStart(2, '0');
      const day = String(date.getDate()).padStart(2, '0');
      const year = date.getFullYear();
      return `${month}/${day}/${year}`;
    } catch (e) {
      return '';
    }
  }

  /**
   * Returns the SLDS doctype icon name based on a file name's extension
   */
  getFileIcon(fileName) {
    if (!fileName) return DEFAULT_FILE_ICON;
    const ext = fileName.split('.').pop()?.toLowerCase();
    return FILE_ICON_MAP[ext] || DEFAULT_FILE_ICON;
  }

  /**
   * Formats bytes into a human-readable string (e.g., "5.2 MB")
   */
  formatFileSize(bytes) {
    if (bytes === 0) return '0 Bytes';
    const units = ['Bytes', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(1024));
    const size = (bytes / Math.pow(1024, i)).toFixed(i === 0 ? 0 : 1);
    return `${size} ${units[i]}`;
  }

  /**
   * Extracts the lowercase file extension from a file name (no dot)
   */
  getFileExtension(fileName) {
    if (!fileName || !fileName.includes('.')) return '';
    return fileName.split('.').pop().toLowerCase();
  }

  /**
   * Validates a list of files for size and type, returns categorized results
   */
  validateFiles(files) {
    const validFiles = [];
    const tooLargeFiles = [];
    const invalidTypeFiles = [];

    for (const file of files) {
      const ext = this.getFileExtension(file.name);
      if (!ext || !ALLOWED_EXTENSIONS.has(ext)) {
        invalidTypeFiles.push(file);
      } else if (file.size > MAX_FILE_SIZE_BYTES) {
        tooLargeFiles.push(file);
      } else {
        validFiles.push(file);
      }
    }

    return { validFiles, tooLargeFiles, invalidTypeFiles };
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DRAG AND DROP METHODS (V2 FEATURE)
  // ─────────────────────────────────────────────────────────────────────────

  /**
   * Returns the CSS class for the drop zone based on drag state
   */
  get dropZoneClass() {
    return this.isDragOver ? 'drop-zone drop-zone-active' : 'drop-zone';
  }

  /**
   * Handles drag enter event
   */
  handleDragEnter(event) {
    event.preventDefault();
    event.stopPropagation();
    this._dragCounter++;

    // Only show drag state if files are being dragged
    if (event.dataTransfer && event.dataTransfer.types.includes('Files')) {
      this.isDragOver = true;
    }
  }

  /**
   * Handles drag over event (required for drop to work)
   */
  handleDragOver(event) {
    event.preventDefault();
    event.stopPropagation();
  }

  /**
   * Handles drag leave event
   */
  handleDragLeave(event) {
    event.preventDefault();
    event.stopPropagation();
    this._dragCounter--;

    // Only remove drag state when leaving the component entirely
    if (this._dragCounter === 0) {
      this.isDragOver = false;
    }
  }

  /**
   * Handles file drop event
   */
  async handleDrop(event) {
    event.preventDefault();
    event.stopPropagation();

    // Reset drag state
    this.isDragOver = false;
    this._dragCounter = 0;

    // Check if a folder is open
    if (!this.currentFolderId) {
      this.showToast('Error', 'Please open a folder first before dropping files.', 'error');
      return;
    }

    // Get dropped files
    const files = event.dataTransfer?.files;
    if (!files || files.length === 0) {
      return;
    }

    // Process the dropped files
    await this.processDroppedFiles(files);
  }

  /**
   * Processes dropped files - validates type and size, handles accordingly
   * @param {FileList} files - The dropped files
   */
  async processDroppedFiles(files) {
    const { validFiles, tooLargeFiles, invalidTypeFiles } = this.validateFiles(files);

    // Build consolidated error messages
    const errorParts = [];

    if (invalidTypeFiles.length > 0) {
      const names = invalidTypeFiles.map(f => {
        const ext = this.getFileExtension(f.name);
        return `${f.name} (.${ext || 'no extension'})`;
      }).join(', ');
      errorParts.push(
        `Unsupported file type: ${names}. Allowed: ${[...ALLOWED_EXTENSIONS].join(', ')}.`
      );
    }

    if (tooLargeFiles.length > 0) {
      const maxSize = this.formatFileSize(MAX_FILE_SIZE_BYTES);
      const names = tooLargeFiles.map(f =>
        `${f.name} (${this.formatFileSize(f.size)})`
      ).join(', ');
      errorParts.push(
        `Exceeds ${maxSize} drag-drop limit: ${names}. Use the Upload button for larger files.`
      );

      // Open upload modal with current folder pre-selected for large files
      this.selectedUploadFolderId = this.currentFolderId;
      await this.handleOpenUploadModal();
    }

    if (errorParts.length > 0) {
      this.showToast('Upload Validation', errorParts.join(' '), 'warning');
    }

    // Upload valid files via base64
    if (validFiles.length > 0) {
      await this.uploadDroppedFiles(validFiles);
    }
  }

  /**
   * Uploads dropped files via base64 encoding
   * @param {Array} files - Array of File objects to upload
   */
  async uploadDroppedFiles(files) {
    this.isUploadingDroppedFiles = true;
    this.droppedFileUploadStatus = `Uploading ${files.length} file(s)...`;

    const results = [];
    const errors = [];

    for (let i = 0; i < files.length; i++) {
      const file = files[i];
      this.droppedFileUploadStatus = `Uploading ${i + 1} of ${files.length}: ${file.name}`;

      try {
        // Read file as base64
        const base64Content = await this.readFileAsBase64(file);

        // Upload via Apex
        const result = await uploadFileFromBase64({
          fileName: file.name,
          base64Content: base64Content,
          folderId: this.currentFolderId
        });

        if (result.success) {
          results.push(result.fileName);
        } else {
          errors.push(`${file.name}: ${result.errorMessage}`);
        }
      } catch (err) {
        errors.push(`${file.name}: ${this.normalizeError(err)}`);
      }
    }

    this.isUploadingDroppedFiles = false;
    this.droppedFileUploadStatus = null;

    // Show results
    if (results.length > 0) {
      this.showToast('Success', `Successfully uploaded ${results.length} file(s).`, 'success');
      // Refresh folder contents
      await this.loadFolderContents();
    }

    if (errors.length > 0) {
      this.showToast('Upload Errors', errors.join('; '), 'error');
    }
  }

  /**
   * Reads a file as base64 string
   * @param {File} file - The file to read
   * @returns {Promise<string>} - Base64 encoded content (without data URL prefix)
   */
  readFileAsBase64(file) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => {
        // Remove the data URL prefix (e.g., "data:image/png;base64,")
        const base64 = reader.result.split(',')[1];
        resolve(base64);
      };
      reader.onerror = () => {
        reject(new Error(`Failed to read file: ${file.name}`));
      };
      reader.readAsDataURL(file);
    });
  }

  /**
   * Shows a toast notification
   * @param {string} title - Toast title
   * @param {string} message - Toast message
   * @param {string} variant - Toast variant (success, error, warning, info)
   */
  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({
      title: title,
      message: message,
      variant: variant
    }));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FILE UPLOAD METHODS
  // ─────────────────────────────────────────────────────────────────────────

  /**
   * Returns whether the upload button should be disabled
   */
  get uploadButtonDisabled() {
    return this.isLoading;
  }

  /**
   * Returns whether the New Folder button should be disabled
   */
  get newFolderButtonDisabled() {
    return this.isLoading;
  }

  /**
   * Returns the record ID to use for lightning-file-upload
   * This is the anchor record, files will be moved to File__c after upload
   */
  get uploadTargetRecordId() {
    return this.recordId;
  }

  /**
   * Returns accepted file formats for the file upload
   * Note: lightning-file-upload uses file extensions
   */
  get acceptedFormats() {
    return [
      '.pdf', '.csv',
      '.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp',
      '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx',
      '.txt', '.rtf', '.zip'
    ];
  }

  /**
   * Opens the upload modal and loads folder options
   */
  async handleOpenUploadModal() {
    this.showUploadModal = true;
    this.uploadError = null;
    this.uploadSuccess = null;
    this.pendingUploads = [];

    // Set default folder to current folder
    if (!this.selectedUploadFolderId) {
      this.selectedUploadFolderId = this.currentFolderId;
    }

    // Load folder options
    await this.loadFolderOptions();
  }

  /**
   * Closes the upload modal and resets state
   */
  handleCloseUploadModal() {
    // Check if we need to refresh before resetting state
    const shouldRefresh = this.pendingUploads.length > 0;

    // Reset modal state
    this.showUploadModal = false;
    this.uploadError = null;
    this.uploadSuccess = null;
    this.selectedUploadFolderId = null;
    this.folderOptions = [];
    this.pendingUploads = [];

    // Refresh folder contents if files were uploaded
    if (shouldRefresh) {
      this.loadFolderContents();
    }
  }

  /**
   * Loads folder options for the dropdown
   */
  async loadFolderOptions() {
    try {
      const folders = await getFoldersForSelect({ parentRecordId: this.recordId });
      this.folderOptions = folders.map(folder => ({
        label: folder.label,
        value: folder.value
      }));

      // If current folder isn't set but we have options, default to first folder
      if (!this.selectedUploadFolderId && this.folderOptions.length > 0) {
        this.selectedUploadFolderId = this.folderOptions[0].value;
      }
    } catch (error) {
      console.error('Error loading folder options:', error);
      this.uploadError = 'Failed to load folders: ' + this.normalizeError(error);
    }
  }

  /**
   * Handles folder selection change in the dropdown
   */
  handleFolderSelectChange(event) {
    this.selectedUploadFolderId = event.detail.value;
  }

  /**
   * Handles the upload finished event from lightning-file-upload
   * Creates File__c records for each uploaded file
   */
  async handleUploadFinished(event) {
    const uploadedFiles = event.detail.files;

    if (!uploadedFiles || uploadedFiles.length === 0) {
      return;
    }

    if (!this.selectedUploadFolderId) {
      this.uploadError = 'Please select a destination folder.';
      return;
    }

    this.isUploading = true;
    this.uploadError = null;
    this.uploadSuccess = null;

    const results = [];
    const errors = [];

    try {
      // Process each uploaded file
      for (const file of uploadedFiles) {
        try {
          const result = await createFileRecord({
            fileName: file.name,
            folderId: this.selectedUploadFolderId,
            contentDocumentId: file.documentId,
            originalLinkedEntityId: this.recordId // Pass the original record to remove auto-link
          });

          if (result.success) {
            results.push(result.fileName);
          } else {
            errors.push(`${file.name}: ${result.errorMessage}`);
          }
        } catch (err) {
          errors.push(`${file.name}: ${this.normalizeError(err)}`);
        }
      }

      // Display results
      if (results.length > 0) {
        this.uploadSuccess = `Successfully uploaded ${results.length} file(s): ${results.join(', ')}`;
        this.pendingUploads = results;
      }

      if (errors.length > 0) {
        this.uploadError = errors.join('; ');
      }

      // Always refresh the folder tree after successful uploads
      if (results.length > 0) {
        await this.loadFolderContents();
      }

    } catch (error) {
      this.uploadError = 'Upload failed: ' + this.normalizeError(error);
    } finally {
      this.isUploading = false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // NEW FOLDER METHODS
  // ─────────────────────────────────────────────────────────────────────────

  /**
   * Opens the new folder modal
   */
  handleOpenNewFolderModal() {
    this.showNewFolderModal = true;
    this.newFolderName = '';
    this.newFolderError = null;
    this.newFolderSuccess = null;
  }

  /**
   * Closes the new folder modal and refreshes if needed
   */
  handleCloseNewFolderModal() {
    const shouldRefresh = this.newFolderSuccess !== null;
    this.showNewFolderModal = false;
    this.newFolderName = '';
    this.newFolderError = null;
    this.newFolderSuccess = null;
    if (shouldRefresh) {
      this.loadFolderContents();
    }
  }

  /**
   * Handles folder name input change
   */
  handleNewFolderNameChange(event) {
    this.newFolderName = event.target.value;
    if (this.newFolderError) {
      this.newFolderError = null;
    }
  }

  /**
   * Validates folder name input
   */
  validateFolderName() {
    if (!this.newFolderName || this.newFolderName.trim().length === 0) {
      this.newFolderError = 'Folder name is required.';
      return false;
    }
    if (this.newFolderName.length > 80) {
      this.newFolderError = 'Folder name must be 80 characters or less.';
      return false;
    }
    const invalidChars = /[<>:"/\\|?*]/;
    if (invalidChars.test(this.newFolderName)) {
      this.newFolderError = 'Folder name contains invalid characters.';
      return false;
    }
    return true;
  }

  /**
   * Creates the new folder
   */
  async handleCreateFolder() {
    if (!this.validateFolderName()) {
      return;
    }

    this.isCreatingFolder = true;
    this.newFolderError = null;
    this.newFolderSuccess = null;

    try {
      const result = await createFolder({
        folderName: this.newFolderName.trim(),
        anchorRecordId: this.recordId,
        parentFolderId: this.currentFolderId
      });

      if (result.success) {
        // Close modal and reset state
        this.showNewFolderModal = false;
        this.newFolderName = '';
        this.newFolderError = null;
        this.newFolderSuccess = null;
        await this.loadFolderContents();
      } else {
        this.newFolderError = result.errorMessage;
      }
    } catch (error) {
      this.newFolderError = 'Failed to create folder: ' + this.normalizeError(error);
    } finally {
      this.isCreatingFolder = false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MOVE FILE METHODS
  // ─────────────────────────────────────────────────────────────────────────

  /**
   * Handles Move File link click - opens the folder selection modal
   */
  async handleMoveFileClick(event) {
    event.preventDefault();
    const fileId = event.currentTarget.dataset.fileId;
    const fileName = event.currentTarget.dataset.fileName;

    if (!fileId || !fileName) {
      return;
    }

    this.fileToMoveId = fileId;
    this.fileToMoveName = fileName;
    this.showMoveFileModal = true;
    this.moveFileError = null;
    this.modalSearchTerm = '';
    this.showSearchResults = false;
    this.fileWasMovedSuccessfully = false;

    // Start by showing all account root folders
    await this.loadAllAccountRootFolders();
  }

  /**
   * Closes the move file modal and resets state
   */
  handleCloseMoveFileModal() {
    const shouldRefresh = this.fileWasMovedSuccessfully;

    this.showMoveFileModal = false;
    this.fileToMoveId = null;
    this.fileToMoveName = '';
    this.moveFileError = null;
    this.isMovingFile = false;
    this.modalCurrentFolderId = null;
    this.modalCurrentRecordId = null;
    this.modalFolderContents = [];
    this.modalBreadcrumbs = [];
    this.showAllAccountsView = false;
    this.accountFolderGroups = [];
    this.modalSearchTerm = '';
    this.modalSearchResults = [];
    this.showSearchResults = false;
    this.fileWasMovedSuccessfully = false;

    // Refresh folder contents if a file was moved
    if (shouldRefresh) {
      this.loadFolderContents();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DELETE FILE METHODS
  // ─────────────────────────────────────────────────────────────────────────

  /**
   * Handles Delete File link click - opens the confirmation modal
   */
  handleDeleteFileClick(event) {
    event.preventDefault();
    const fileId = event.currentTarget.dataset.fileId;
    const fileName = event.currentTarget.dataset.fileName;

    if (!fileId || !fileName) {
      return;
    }

    this.fileToDeleteId = fileId;
    this.fileToDeleteName = fileName;
    this.showDeleteFileModal = true;
    this.deleteFileError = null;
    this.fileWasDeletedSuccessfully = false;
  }

  /**
   * Closes the delete file modal and refreshes if needed
   */
  handleCloseDeleteFileModal() {
    const shouldRefresh = this.fileWasDeletedSuccessfully;

    this.showDeleteFileModal = false;
    this.fileToDeleteId = null;
    this.fileToDeleteName = '';
    this.deleteFileError = null;
    this.isDeletingFile = false;
    this.fileWasDeletedSuccessfully = false;

    // Refresh folder contents if a file was deleted
    if (shouldRefresh) {
      this.loadFolderContents();
    }
  }

  /**
   * Confirms and executes the file deletion
   */
  async handleConfirmDeleteFile() {
    if (!this.fileToDeleteId) {
      return;
    }

    this.isDeletingFile = true;
    this.deleteFileError = null;

    try {
      const result = await deleteFile({
        fileId: this.fileToDeleteId
      });

      if (result.success) {
        // Success - mark as successful and close modal (which will trigger refresh)
        this.fileWasDeletedSuccessfully = true;
        this.isDeletingFile = false;
        this.handleCloseDeleteFileModal();
      } else {
        this.deleteFileError = result.errorMessage;
        this.isDeletingFile = false;
      }
    } catch (error) {
      console.error('Error deleting file:', error);
      this.deleteFileError = 'Failed to delete file: ' + this.normalizeError(error);
      this.isDeletingFile = false;
    }
  }

  /**
   * Loads all account root folders for the modal
   */
  async loadAllAccountRootFolders() {
    this.isLoadingModalFolders = true;
    this.showAllAccountsView = true;
    this.modalCurrentFolderId = null;
    this.modalCurrentRecordId = null;
    this.modalBreadcrumbs = [];

    try {
      const groups = await getAllAccountRootFolders();
      this.accountFolderGroups = groups || [];
    } catch (error) {
      console.error('Error loading account root folders:', error);
      this.moveFileError = 'Failed to load folders: ' + this.normalizeError(error);
      this.accountFolderGroups = [];
    } finally {
      this.isLoadingModalFolders = false;
    }
  }

  /**
   * Handles clicking "All Accounts" in modal breadcrumb
   */
  async handleModalShowAllAccounts() {
    await this.loadAllAccountRootFolders();
  }

  /**
   * Handles clicking a folder in the modal (navigation)
   */
  async handleModalFolderClick(event) {
    event.preventDefault();
    const folderId = event.currentTarget.dataset.folderId;
    const parentRecordId = event.currentTarget.dataset.parentRecordId;

    if (!folderId) {
      return;
    }

    // Get folder name from the link text
    const folderName = event.currentTarget.textContent.trim();

    await this.navigateToModalFolder(folderId, folderName, parentRecordId);
  }

  /**
   * Navigates to a folder within the modal
   */
  async navigateToModalFolder(folderId, folderName, parentRecordId) {
    this.isLoadingModalFolders = true;
    this.showAllAccountsView = false;
    this.modalCurrentFolderId = folderId;
    this.modalCurrentRecordId = parentRecordId || this.modalCurrentRecordId;

    // Add to breadcrumbs
    this.modalBreadcrumbs = [...this.modalBreadcrumbs, {
      id: folderId,
      label: folderName,
      isLast: true
    }];

    await this.loadModalFolderContents();
  }

  /**
   * Loads folder contents for the modal
   */
  async loadModalFolderContents() {
    try {
      const data = await getFolderContents({
        parentRecordId: this.modalCurrentRecordId,
        currentFolderId: this.modalCurrentFolderId
      });

      // Filter to only show folders (no files)
      this.modalFolderContents = (data || [])
        .filter(item => item.nodeType === 'Folder')
        .map(item => ({
          recordId: item.recordId,
          label: item.label
        }));

    } catch (error) {
      console.error('Error loading modal folder contents:', error);
      this.moveFileError = 'Failed to load folder contents: ' + this.normalizeError(error);
      this.modalFolderContents = [];
    } finally {
      this.isLoadingModalFolders = false;
    }
  }

  /**
   * Handles breadcrumb click in modal
   */
  async handleModalBreadcrumbClick(event) {
    event.preventDefault();
    const targetId = event.currentTarget.dataset.breadcrumbId;

    const index = this.modalBreadcrumbs.findIndex(b => b.id === targetId);
    if (index === -1) return;

    // Remove breadcrumbs after the clicked one
    this.modalBreadcrumbs = this.modalBreadcrumbs.slice(0, index + 1);

    // Update current folder
    this.modalCurrentFolderId = this.modalBreadcrumbs.length > 0
      ? this.modalBreadcrumbs[this.modalBreadcrumbs.length - 1].id
      : null;

    // Update isLast flags
    this.modalBreadcrumbs = this.modalBreadcrumbs.map((crumb, idx) => ({
      ...crumb,
      isLast: idx === this.modalBreadcrumbs.length - 1
    }));

    await this.loadModalFolderContents();
  }

  /**
   * Handles search input change
   */
  handleModalSearchChange(event) {
    this.modalSearchTerm = event.target.value;
  }

  /**
   * Handles Enter key press in search box
   */
  async handleModalSearchKeyup(event) {
    if (event.key === 'Enter' || event.keyCode === 13) {
      await this.performModalSearch();
    }
  }

  /**
   * Performs the folder search
   */
  async performModalSearch() {
    if (!this.modalSearchTerm || this.modalSearchTerm.trim().length === 0) {
      return;
    }

    this.isLoadingModalFolders = true;
    this.showSearchResults = true;

    try {
      const results = await searchFolders({ searchTerm: this.modalSearchTerm.trim() });
      this.modalSearchResults = results || [];
    } catch (error) {
      console.error('Error searching folders:', error);
      this.moveFileError = 'Search failed: ' + this.normalizeError(error);
      this.modalSearchResults = [];
    } finally {
      this.isLoadingModalFolders = false;
    }
  }

  /**
   * Clears the search and returns to folder navigation
   */
  async handleClearModalSearch() {
    this.modalSearchTerm = '';
    this.showSearchResults = false;
    this.modalSearchResults = [];

    // If we were navigating folders, stay there; otherwise show all accounts
    if (this.modalCurrentFolderId) {
      await this.loadModalFolderContents();
    } else {
      await this.loadAllAccountRootFolders();
    }
  }

  /**
   * Handles selecting a search result
   */
  async handleSelectSearchResult(event) {
    const folderId = event.currentTarget.dataset.folderId;

    if (!folderId) {
      return;
    }

    await this.moveFileToFolder(folderId);
  }

  /**
   * Handles selecting a folder from the navigation view
   */
  async handleSelectModalFolder(event) {
    event.preventDefault();
    const folderId = event.currentTarget.dataset.folderId;

    if (!folderId) {
      return;
    }

    await this.moveFileToFolder(folderId);
  }

  /**
   * Handles selecting the current folder
   */
  async handleSelectCurrentModalFolder() {
    if (!this.modalCurrentFolderId) {
      return;
    }

    await this.moveFileToFolder(this.modalCurrentFolderId);
  }

  /**
   * Moves the file to the selected folder
   */
  async moveFileToFolder(destinationFolderId) {
    if (!this.fileToMoveId || !destinationFolderId) {
      return;
    }

    this.isMovingFile = true;
    this.moveFileError = null;

    try {
      const result = await moveFile({
        fileId: this.fileToMoveId,
        destinationFolderId: destinationFolderId
      });

      if (result.success) {
        // Success - mark as successful and close modal (which will trigger refresh)
        this.fileWasMovedSuccessfully = true;
        this.isMovingFile = false;
        this.handleCloseMoveFileModal();
      } else {
        this.moveFileError = result.errorMessage;
        this.isMovingFile = false;
      }
    } catch (error) {
      console.error('Error moving file:', error);
      this.moveFileError = 'Failed to move file: ' + this.normalizeError(error);
      this.isMovingFile = false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MOVE FILE MODAL COMPUTED PROPERTIES
  // ─────────────────────────────────────────────────────────────────────────

  /**
   * Returns true if breadcrumbs should be shown in modal
   */
  get showModalBreadcrumbs() {
    return !this.showSearchResults && (this.showAllAccountsView || this.modalBreadcrumbs.length > 0);
  }

  /**
   * Returns true if "All Accounts" link should be shown
   */
  get showAllAccountsLink() {
    return !this.showAllAccountsView;
  }

  /**
   * Returns true if "View All Account Folders" button should be shown
   */
  get showViewAllAccountFoldersButton() {
    return !this.showSearchResults && !this.showAllAccountsView && this.modalBreadcrumbs.length > 0;
  }

  /**
   * Returns a flattened list of all folders from all account groups
   */
  get flattenedAccountFolders() {
    const flattened = [];
    for (const group of this.accountFolderGroups) {
      for (const folder of group.folders) {
        flattened.push({
          ...folder,
          parentRecordId: group.accountId
        });
      }
    }
    return flattened;
  }

  /**
   * Returns true if there are folders in the modal
   */
  get hasModalFolders() {
    return this.modalFolderContents && this.modalFolderContents.length > 0;
  }

  /**
   * Returns true if there are search results
   */
  get hasModalSearchResults() {
    return this.modalSearchResults && this.modalSearchResults.length > 0;
  }

  /**
   * Returns true if the "Select Current Folder" button should be enabled
   */
  get canSelectCurrentModalFolder() {
    return this.modalCurrentFolderId !== null && !this.showSearchResults && !this.showAllAccountsView;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ACTION MENU HANDLER
  // ─────────────────────────────────────────────────────────────────────────

  /**
   * Unified handler for action menu selections
   * Routes to appropriate handler based on action type
   */
  handleActionSelect(event) {
    const action = event.detail.value;
    const target = event.currentTarget;
    const recordId = target.dataset.recordId;
    const itemName = target.dataset.itemName;
    const fileUrl = target.dataset.fileUrl;
    const contentDocId = target.dataset.contentDocumentId;

    switch (action) {
      // File actions
      case 'download':
        if (fileUrl) {
          window.open(fileUrl, '_blank', 'noopener,noreferrer');
        }
        break;

      case 'view':
        // Navigate to the File__c record page
        this[NavigationMixin.Navigate]({
          type: "standard__recordPage",
          attributes: {
            recordId: recordId,
            actionName: "view"
          }
        });
        break;

      case 'move':
        this.fileToMoveId = recordId;
        this.fileToMoveName = itemName;
        this.showMoveFileModal = true;
        this.moveFileError = null;
        this.modalSearchTerm = '';
        this.showSearchResults = false;
        this.fileWasMovedSuccessfully = false;
        this.loadAllAccountRootFolders();
        break;

      case 'delete':
        this.fileToDeleteId = recordId;
        this.fileToDeleteName = itemName;
        this.showDeleteFileModal = true;
        this.deleteFileError = null;
        this.fileWasDeletedSuccessfully = false;
        break;

      // Folder actions
      case 'rename':
        this.openRenameFolderModal(recordId, itemName);
        break;

      case 'moveFolder':
        this.openMoveFolderModal(recordId, itemName);
        break;

      case 'deleteFolder':
        this.openDeleteFolderModal(recordId, itemName);
        break;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RENAME FOLDER METHODS
  // ─────────────────────────────────────────────────────────────────────────

  /**
   * Opens the rename folder modal
   */
  openRenameFolderModal(folderId, folderName) {
    this.folderToRenameId = folderId;
    this.folderToRenameName = folderName;
    this.newFolderNameInput = folderName;
    this.renameFolderError = null;
    this.isRenamingFolder = false;
    this.showRenameFolderModal = true;
  }

  /**
   * Handles input change for rename folder
   */
  handleRenameFolderInputChange(event) {
    this.newFolderNameInput = event.target.value;
  }

  /**
   * Closes the rename folder modal
   */
  handleCloseRenameFolderModal() {
    this.showRenameFolderModal = false;
    this.folderToRenameId = null;
    this.folderToRenameName = '';
    this.newFolderNameInput = '';
    this.renameFolderError = null;
    this.isRenamingFolder = false;
  }

  /**
   * Confirms and executes the folder rename
   */
  async handleConfirmRenameFolder() {
    if (!this.folderToRenameId || !this.newFolderNameInput) {
      this.renameFolderError = 'Please enter a folder name.';
      return;
    }

    if (this.newFolderNameInput === this.folderToRenameName) {
      this.handleCloseRenameFolderModal();
      return;
    }

    this.isRenamingFolder = true;
    this.renameFolderError = null;

    try {
      const result = await renameFolder({
        folderId: this.folderToRenameId,
        newName: this.newFolderNameInput
      });

      if (result.success) {
        this.handleCloseRenameFolderModal();
        await this.loadFolderContents();
        // Update breadcrumbs if the renamed folder is in the path
        this.breadcrumbs = this.breadcrumbs.map(crumb => {
          if (crumb.id === this.folderToRenameId) {
            return { ...crumb, label: this.newFolderNameInput };
          }
          return crumb;
        });
      } else {
        this.renameFolderError = result.errorMessage || 'Failed to rename folder.';
        this.isRenamingFolder = false;
      }
    } catch (error) {
      console.error('Error renaming folder:', error);
      this.renameFolderError = 'Failed to rename folder: ' + this.normalizeError(error);
      this.isRenamingFolder = false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DELETE FOLDER METHODS
  // ─────────────────────────────────────────────────────────────────────────

  /**
   * Opens the delete folder confirmation modal
   */
  async openDeleteFolderModal(folderId, folderName) {
    this.folderToDeleteId = folderId;
    this.folderToDeleteName = folderName;
    this.deleteFolderError = null;
    this.isDeletingFolder = false;
    this.folderContentsCount = null;
    this.showDeleteFolderModal = true;

    // Load folder contents count
    try {
      const countResult = await getFolderContentsCount({ folderId: folderId });
      if (countResult.success) {
        this.folderContentsCount = countResult;
      }
    } catch (error) {
      console.error('Error getting folder contents count:', error);
    }
  }

  /**
   * Closes the delete folder modal
   */
  handleCloseDeleteFolderModal() {
    this.showDeleteFolderModal = false;
    this.folderToDeleteId = null;
    this.folderToDeleteName = '';
    this.deleteFolderError = null;
    this.isDeletingFolder = false;
    this.folderContentsCount = null;
  }

  /**
   * Confirms and executes the folder deletion
   */
  async handleConfirmDeleteFolder() {
    if (!this.folderToDeleteId) {
      return;
    }

    this.isDeletingFolder = true;
    this.deleteFolderError = null;

    try {
      const result = await deleteFolder({ folderId: this.folderToDeleteId });

      if (result.success) {
        // Remove from breadcrumbs if deleted folder was in path
        const deletedFolderIndex = this.breadcrumbs.findIndex(crumb => crumb.id === this.folderToDeleteId);
        if (deletedFolderIndex !== -1) {
          // Navigate up to parent of deleted folder
          if (deletedFolderIndex > 0) {
            this.breadcrumbs = this.breadcrumbs.slice(0, deletedFolderIndex);
            this.currentFolderId = this.breadcrumbs[this.breadcrumbs.length - 1].id;
          } else {
            this.breadcrumbs = [];
            this.currentFolderId = null;
          }
        }
        this.handleCloseDeleteFolderModal();
        await this.loadFolderContents();
      } else {
        this.deleteFolderError = result.errorMessage || 'Failed to delete folder.';
        this.isDeletingFolder = false;
      }
    } catch (error) {
      console.error('Error deleting folder:', error);
      this.deleteFolderError = 'Failed to delete folder: ' + this.normalizeError(error);
      this.isDeletingFolder = false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MOVE FOLDER METHODS
  // ─────────────────────────────────────────────────────────────────────────

  /**
   * Opens the move folder modal
   */
  async openMoveFolderModal(folderId, folderName) {
    this.folderToMoveId = folderId;
    this.folderToMoveName = folderName;
    this.moveFolderError = null;
    this.isMovingFolder = false;
    this.moveFolderCurrentFolderId = null;
    this.moveFolderCurrentRecordId = this.recordId;
    this.moveFolderContents = [];
    this.moveFolderBreadcrumbs = [];
    this.showMoveFolderAllAccountsView = false;
    this.moveFolderAccountFolderGroups = [];
    this.showMoveFolderModal = true;

    await this.loadMoveFolderAccountRootFolders();
  }

  /**
   * Loads all account root folders for the move folder modal
   */
  async loadMoveFolderAccountRootFolders() {
    this.isLoadingMoveFolderFolders = true;

    try {
      const groups = await getAllAccountRootFolders();
      this.moveFolderAccountFolderGroups = groups || [];
      this.showMoveFolderAllAccountsView = true;
    } catch (error) {
      console.error('Error loading account root folders:', error);
      this.moveFolderError = 'Failed to load folders: ' + this.normalizeError(error);
      this.moveFolderAccountFolderGroups = [];
    } finally {
      this.isLoadingMoveFolderFolders = false;
    }
  }

  /**
   * Handles folder click in move folder modal
   */
  async handleMoveFolderFolderClick(event) {
    event.preventDefault();
    const folderId = event.currentTarget.dataset.folderId;
    const parentRecordId = event.currentTarget.dataset.parentRecordId;

    if (!folderId) return;

    // Don't allow navigating into the folder being moved or its descendants
    if (folderId === this.folderToMoveId) {
      this.moveFolderError = 'Cannot move a folder into itself.';
      return;
    }

    this.moveFolderError = null;
    this.showMoveFolderAllAccountsView = false;

    // Find folder name from current contents or flattened list
    let folderName = 'Unknown';
    const flatFolders = this.moveFolderFlattenedAccountFolders;
    const foundFolder = flatFolders.find(f => f.recordId === folderId) ||
                        this.moveFolderContents.find(f => f.recordId === folderId);
    if (foundFolder) {
      folderName = foundFolder.label;
    }

    // Update breadcrumbs
    this.moveFolderBreadcrumbs = [...this.moveFolderBreadcrumbs, { id: folderId, label: folderName }];
    this.moveFolderCurrentFolderId = folderId;
    this.moveFolderCurrentRecordId = parentRecordId;

    await this.loadMoveFolderContents();
  }

  /**
   * Loads folder contents for the move folder modal
   */
  async loadMoveFolderContents() {
    this.isLoadingMoveFolderFolders = true;

    try {
      const contents = await getFolderContents({
        parentRecordId: this.moveFolderCurrentRecordId,
        currentFolderId: this.moveFolderCurrentFolderId
      });

      // Filter out the folder being moved and only show folders
      this.moveFolderContents = (contents || [])
        .filter(item => item.nodeType === 'Folder' && item.recordId !== this.folderToMoveId);
    } catch (error) {
      console.error('Error loading move folder contents:', error);
      this.moveFolderError = 'Failed to load folder contents: ' + this.normalizeError(error);
      this.moveFolderContents = [];
    } finally {
      this.isLoadingMoveFolderFolders = false;
    }
  }

  /**
   * Handles breadcrumb click in move folder modal
   */
  async handleMoveFolderBreadcrumbClick(event) {
    event.preventDefault();
    const targetId = event.currentTarget.dataset.breadcrumbId;
    const index = this.moveFolderBreadcrumbs.findIndex(b => b.id === targetId);
    if (index === -1) return;

    this.moveFolderBreadcrumbs = this.moveFolderBreadcrumbs.slice(0, index + 1);
    this.moveFolderCurrentFolderId = this.moveFolderBreadcrumbs.length > 0
      ? this.moveFolderBreadcrumbs[this.moveFolderBreadcrumbs.length - 1].id
      : null;

    await this.loadMoveFolderContents();
  }

  /**
   * Shows all accounts view in move folder modal
   */
  handleMoveFolderShowAllAccounts() {
    this.showMoveFolderAllAccountsView = true;
    this.moveFolderBreadcrumbs = [];
    this.moveFolderCurrentFolderId = null;
    this.moveFolderContents = [];
  }

  /**
   * Selects a folder as the move destination
   */
  async handleSelectMoveFolderDestination(event) {
    const destinationFolderId = event.currentTarget.dataset.folderId;
    await this.executeMoveFolderTo(destinationFolderId);
  }

  /**
   * Selects the current folder as the move destination
   */
  async handleSelectCurrentMoveFolderDestination() {
    await this.executeMoveFolderTo(this.moveFolderCurrentFolderId);
  }

  /**
   * Executes the folder move operation
   */
  async executeMoveFolderTo(destinationFolderId) {
    if (!this.folderToMoveId) return;

    // Validate not moving to self
    if (destinationFolderId === this.folderToMoveId) {
      this.moveFolderError = 'Cannot move a folder into itself.';
      return;
    }

    this.isMovingFolder = true;
    this.moveFolderError = null;

    try {
      const result = await moveFolder({
        folderId: this.folderToMoveId,
        destinationFolderId: destinationFolderId
      });

      if (result.success) {
        this.handleCloseMoveFolderModal();
        await this.loadFolderContents();
      } else {
        this.moveFolderError = result.errorMessage || 'Failed to move folder.';
        this.isMovingFolder = false;
      }
    } catch (error) {
      console.error('Error moving folder:', error);
      this.moveFolderError = 'Failed to move folder: ' + this.normalizeError(error);
      this.isMovingFolder = false;
    }
  }

  /**
   * Closes the move folder modal
   */
  handleCloseMoveFolderModal() {
    this.showMoveFolderModal = false;
    this.folderToMoveId = null;
    this.folderToMoveName = '';
    this.moveFolderError = null;
    this.isMovingFolder = false;
    this.moveFolderCurrentFolderId = null;
    this.moveFolderCurrentRecordId = null;
    this.moveFolderContents = [];
    this.moveFolderBreadcrumbs = [];
    this.showMoveFolderAllAccountsView = false;
    this.moveFolderAccountFolderGroups = [];
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MOVE FOLDER GETTERS
  // ─────────────────────────────────────────────────────────────────────────

  /**
   * Returns true if there are folders in the move folder modal
   */
  get hasMoveFolderFolders() {
    return this.moveFolderContents && this.moveFolderContents.length > 0;
  }

  /**
   * Returns flattened list of folders from all account groups for move folder
   */
  get moveFolderFlattenedAccountFolders() {
    const flattened = [];
    for (const group of this.moveFolderAccountFolderGroups) {
      for (const folder of group.folders) {
        // Exclude the folder being moved
        if (folder.recordId !== this.folderToMoveId) {
          flattened.push({
            ...folder,
            parentRecordId: group.accountId
          });
        }
      }
    }
    return flattened;
  }

  /**
   * Returns true if breadcrumbs should be shown in move folder modal
   */
  get showMoveFolderBreadcrumbs() {
    return !this.showMoveFolderAllAccountsView || this.moveFolderBreadcrumbs.length > 0;
  }

  /**
   * Returns true if "All Accounts" link should be shown in move folder modal
   */
  get showMoveFolderAllAccountsLink() {
    return !this.showMoveFolderAllAccountsView;
  }

  /**
   * Returns true if "View All Account Folders" button should be shown
   */
  get showMoveFolderViewAllButton() {
    return !this.showMoveFolderAllAccountsView && this.moveFolderBreadcrumbs.length > 0;
  }

  /**
   * Returns true if the "Select Current Folder" button should be enabled
   */
  get canSelectCurrentMoveFolderDestination() {
    return this.moveFolderCurrentFolderId !== null &&
           this.moveFolderCurrentFolderId !== this.folderToMoveId &&
           !this.showMoveFolderAllAccountsView;
  }
}
