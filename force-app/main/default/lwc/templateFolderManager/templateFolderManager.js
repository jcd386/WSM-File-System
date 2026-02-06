import { LightningElement, api } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getTemplateFolders from "@salesforce/apex/TemplateFolderService.getTemplateFolders";
import createTemplateFolder from "@salesforce/apex/TemplateFolderService.createTemplateFolder";
import renameTemplateFolder from "@salesforce/apex/TemplateFolderService.renameTemplateFolder";
import moveTemplateFolder from "@salesforce/apex/TemplateFolderService.moveTemplateFolder";
import deleteTemplateFolder from "@salesforce/apex/TemplateFolderService.deleteTemplateFolder";
import getChildCount from "@salesforce/apex/TemplateFolderService.getChildCount";
import getMoveTargets from "@salesforce/apex/TemplateFolderService.getMoveTargets";

export default class TemplateFolderManager extends LightningElement {
  @api recordId;

  // Data
  templateFolders = [];

  // UI State
  isLoading = false;
  error = null;

  // Create Modal State
  showCreateModal = false;
  newFolderName = "";
  newFolderParentId = null;
  newFolderParentName = "";
  createError = null;
  isCreating = false;

  // Rename Modal State
  showRenameModal = false;
  folderToRenameId = null;
  folderToRenameName = "";
  newNameInput = "";
  renameError = null;
  isRenaming = false;

  // Move Modal State
  showMoveModal = false;
  folderToMoveId = null;
  folderToMoveName = "";
  selectedMoveTargetId = null;
  moveTargets = [];
  moveError = null;
  isMoving = false;
  isLoadingMoveTargets = false;

  // Delete Modal State
  showDeleteModal = false;
  folderToDeleteId = null;
  folderToDeleteName = "";
  deleteChildCount = 0;
  deleteError = null;
  isDeleting = false;

  // ─────────────────────────────────────────────────────────────────────────
  // LIFECYCLE
  // ─────────────────────────────────────────────────────────────────────────

  connectedCallback() {
    if (this.recordId) {
      this.loadTemplateFolders();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DATA LOADING
  // ─────────────────────────────────────────────────────────────────────────

  async loadTemplateFolders() {
    this.isLoading = true;
    this.error = null;

    try {
      const data = await getTemplateFolders({
        folderTemplateSetId: this.recordId
      });
      this.templateFolders = data || [];
    } catch (err) {
      this.error = this.normalizeError(err);
      this.templateFolders = [];
    } finally {
      this.isLoading = false;
    }
  }

  async loadMoveTargets(excludeFolderId) {
    this.isLoadingMoveTargets = true;
    this.moveError = null;

    try {
      const targets = await getMoveTargets({
        folderId: excludeFolderId,
        folderTemplateSetId: this.recordId
      });
      this.moveTargets = targets || [];
    } catch (err) {
      this.moveError = this.normalizeError(err);
      this.moveTargets = [];
    } finally {
      this.isLoadingMoveTargets = false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GETTERS
  // ─────────────────────────────────────────────────────────────────────────

  get hasTemplateFolders() {
    return this.templateFolders && this.templateFolders.length > 0;
  }

  get sortedTemplateFolders() {
    return this.templateFolders.map((folder) => ({
      ...folder,
      indentStyle: `padding-left: ${folder.level * 1.5 + 0.5}rem`
    }));
  }

  get createModalTitle() {
    return this.newFolderParentName
      ? `Create Subfolder in "${this.newFolderParentName}"`
      : "Create Root Folder";
  }

  get moveTargetOptions() {
    const options = [{ label: "Root Level (No Parent)", value: "" }];
    for (const target of this.moveTargets) {
      const indent = "  ".repeat(target.level);
      options.push({
        label: `${indent}${target.label}`,
        value: target.recordId
      });
    }
    return options;
  }

  get hasMoveTargets() {
    return this.moveTargets && this.moveTargets.length > 0;
  }

  get deleteWarningMessage() {
    if (this.deleteChildCount > 0) {
      return `This will also delete ${this.deleteChildCount} subfolder(s).`;
    }
    return "";
  }

  get hasDeleteWarning() {
    return this.deleteChildCount > 0;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ACTION BUTTON HANDLERS
  // ─────────────────────────────────────────────────────────────────────────

  handleAddSubfolderClick(event) {
    const folderId = event.currentTarget.dataset.folderId;
    const folderName = event.currentTarget.dataset.folderName;
    this.openCreateModal(folderId, folderName);
  }

  handleRenameClick(event) {
    const folderId = event.currentTarget.dataset.folderId;
    const folderName = event.currentTarget.dataset.folderName;
    this.openRenameModal(folderId, folderName);
  }

  handleMoveClick(event) {
    const folderId = event.currentTarget.dataset.folderId;
    const folderName = event.currentTarget.dataset.folderName;
    this.openMoveModal(folderId, folderName);
  }

  handleDeleteClick(event) {
    const folderId = event.currentTarget.dataset.folderId;
    const folderName = event.currentTarget.dataset.folderName;
    this.openDeleteModal(folderId, folderName);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CREATE FOLDER
  // ─────────────────────────────────────────────────────────────────────────

  handleOpenCreateModal() {
    this.openCreateModal(null, null);
  }

  openCreateModal(parentId, parentName) {
    this.newFolderName = "";
    this.newFolderParentId = parentId;
    this.newFolderParentName = parentName || "";
    this.createError = null;
    this.isCreating = false;
    this.showCreateModal = true;
  }

  handleCreateNameChange(event) {
    this.newFolderName = event.target.value;
  }

  async handleCreateFolder() {
    if (!this.newFolderName || this.newFolderName.trim().length === 0) {
      this.createError = "Folder name is required.";
      return;
    }

    this.isCreating = true;
    this.createError = null;

    try {
      const result = await createTemplateFolder({
        name: this.newFolderName.trim(),
        folderTemplateSetId: this.recordId,
        parentFolderId: this.newFolderParentId
      });

      if (result.success) {
        this.handleCloseCreateModal();
        await this.loadTemplateFolders();
        this.showToast("Success", `Folder "${result.recordName}" created.`, "success");
      } else {
        this.createError = result.errorMessage;
      }
    } catch (err) {
      this.createError = this.normalizeError(err);
    } finally {
      this.isCreating = false;
    }
  }

  handleCloseCreateModal() {
    this.showCreateModal = false;
    this.newFolderName = "";
    this.newFolderParentId = null;
    this.newFolderParentName = "";
    this.createError = null;
    this.isCreating = false;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RENAME FOLDER
  // ─────────────────────────────────────────────────────────────────────────

  openRenameModal(folderId, folderName) {
    this.folderToRenameId = folderId;
    this.folderToRenameName = folderName;
    this.newNameInput = folderName;
    this.renameError = null;
    this.isRenaming = false;
    this.showRenameModal = true;
  }

  handleRenameInputChange(event) {
    this.newNameInput = event.target.value;
  }

  async handleRenameFolder() {
    if (!this.newNameInput || this.newNameInput.trim().length === 0) {
      this.renameError = "Folder name is required.";
      return;
    }

    if (this.newNameInput.trim() === this.folderToRenameName) {
      this.handleCloseRenameModal();
      return;
    }

    this.isRenaming = true;
    this.renameError = null;

    try {
      const result = await renameTemplateFolder({
        folderId: this.folderToRenameId,
        newName: this.newNameInput.trim()
      });

      if (result.success) {
        this.handleCloseRenameModal();
        await this.loadTemplateFolders();
        this.showToast("Success", `Folder renamed to "${result.recordName}".`, "success");
      } else {
        this.renameError = result.errorMessage;
      }
    } catch (err) {
      this.renameError = this.normalizeError(err);
    } finally {
      this.isRenaming = false;
    }
  }

  handleCloseRenameModal() {
    this.showRenameModal = false;
    this.folderToRenameId = null;
    this.folderToRenameName = "";
    this.newNameInput = "";
    this.renameError = null;
    this.isRenaming = false;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MOVE FOLDER
  // ─────────────────────────────────────────────────────────────────────────

  async openMoveModal(folderId, folderName) {
    this.folderToMoveId = folderId;
    this.folderToMoveName = folderName;
    this.selectedMoveTargetId = null;
    this.moveError = null;
    this.isMoving = false;
    this.showMoveModal = true;

    await this.loadMoveTargets(folderId);
  }

  handleMoveTargetChange(event) {
    this.selectedMoveTargetId = event.detail.value;
  }

  async handleMoveFolder() {
    this.isMoving = true;
    this.moveError = null;

    try {
      const result = await moveTemplateFolder({
        folderId: this.folderToMoveId,
        newParentFolderId: this.selectedMoveTargetId || null
      });

      if (result.success) {
        this.handleCloseMoveModal();
        await this.loadTemplateFolders();
        this.showToast("Success", `Folder "${result.recordName}" moved.`, "success");
      } else {
        this.moveError = result.errorMessage;
      }
    } catch (err) {
      this.moveError = this.normalizeError(err);
    } finally {
      this.isMoving = false;
    }
  }

  handleCloseMoveModal() {
    this.showMoveModal = false;
    this.folderToMoveId = null;
    this.folderToMoveName = "";
    this.selectedMoveTargetId = null;
    this.moveTargets = [];
    this.moveError = null;
    this.isMoving = false;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DELETE FOLDER
  // ─────────────────────────────────────────────────────────────────────────

  async openDeleteModal(folderId, folderName) {
    this.folderToDeleteId = folderId;
    this.folderToDeleteName = folderName;
    this.deleteChildCount = 0;
    this.deleteError = null;
    this.isDeleting = false;
    this.showDeleteModal = true;

    // Get child count for warning
    try {
      const result = await getChildCount({ folderId: folderId });
      if (result.success) {
        this.deleteChildCount = result.childCount || 0;
      }
    } catch (err) {
      console.error("Error getting child count:", err);
    }
  }

  async handleConfirmDelete() {
    this.isDeleting = true;
    this.deleteError = null;

    try {
      const result = await deleteTemplateFolder({
        folderId: this.folderToDeleteId
      });

      if (result.success) {
        const deletedName = this.folderToDeleteName;
        this.handleCloseDeleteModal();
        await this.loadTemplateFolders();
        this.showToast("Success", `Folder "${deletedName}" deleted.`, "success");
      } else {
        this.deleteError = result.errorMessage;
      }
    } catch (err) {
      this.deleteError = this.normalizeError(err);
    } finally {
      this.isDeleting = false;
    }
  }

  handleCloseDeleteModal() {
    this.showDeleteModal = false;
    this.folderToDeleteId = null;
    this.folderToDeleteName = "";
    this.deleteChildCount = 0;
    this.deleteError = null;
    this.isDeleting = false;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UTILITIES
  // ─────────────────────────────────────────────────────────────────────────

  normalizeError(err) {
    if (!err) return "Unknown error";
    const body = err.body;
    if (Array.isArray(body)) return body.map((e) => e.message).join("; ");
    return body?.message || err.message || JSON.stringify(err);
  }

  showToast(title, message, variant) {
    this.dispatchEvent(
      new ShowToastEvent({
        title: title,
        message: message,
        variant: variant
      })
    );
  }
}
