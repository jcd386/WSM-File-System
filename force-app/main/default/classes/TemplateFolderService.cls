/**
 * Service class for managing Template_Folder__c records
 * Used by the templateFolderManager LWC on Folder_Template_Set__c record pages
 */
public with sharing class TemplateFolderService {

    // Test-only: bypass WITH SECURITY_ENFORCED for deployment test context
    @TestVisible private static Boolean testBypassFLS = false;

    // ─────────────────────────────────────────────────────────────────────────
    // INNER CLASSES
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Represents a template folder in the tree structure
     */
    public class TreeNode implements Comparable {
        @AuraEnabled public String key;
        @AuraEnabled public String label;
        @AuraEnabled public Id recordId;
        @AuraEnabled public Id parentFolderId;
        @AuraEnabled public Integer level;
        @AuraEnabled public Integer childCount;
        @AuraEnabled public Boolean hasChildren;

        public Integer compareTo(Object other) {
            TreeNode otherNode = (TreeNode) other;
            return this.label.compareTo(otherNode.label);
        }
    }

    /**
     * Result wrapper for create/rename/move operations
     */
    public class OperationResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String errorMessage;
        @AuraEnabled public Id recordId;
        @AuraEnabled public String recordName;

        public OperationResult(Boolean success, String errorMessage) {
            this.success = success;
            this.errorMessage = errorMessage;
        }

        public OperationResult(Boolean success, Id recordId, String recordName) {
            this.success = success;
            this.recordId = recordId;
            this.recordName = recordName;
        }
    }

    /**
     * Result wrapper for delete operations
     */
    public class DeleteResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String errorMessage;
        @AuraEnabled public Integer deletedCount;
        @AuraEnabled public Integer childCount;

        public DeleteResult(Boolean success, String errorMessage) {
            this.success = success;
            this.errorMessage = errorMessage;
        }

        public DeleteResult(Boolean success, Integer deletedCount) {
            this.success = success;
            this.deletedCount = deletedCount;
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // PUBLIC METHODS
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Gets all template folders for a Folder Template Set, sorted hierarchically
     * @param folderTemplateSetId The Folder_Template_Set__c record Id
     * @return List of TreeNode objects with hierarchy level information
     */
    @AuraEnabled
    public static List<TreeNode> getTemplateFolders(String folderTemplateSetId) {
        if (String.isBlank(folderTemplateSetId)) {
            return new List<TreeNode>();
        }

        // Query all template folders for this set
        List<Template_Folder__c> folders;
        if (testBypassFLS) {
            folders = [SELECT Id, Name, Parent_Template_Folder__c FROM Template_Folder__c WHERE Folder_Template_Set__c = :folderTemplateSetId ORDER BY Name ASC];
        } else {
            folders = [SELECT Id, Name, Parent_Template_Folder__c FROM Template_Folder__c WHERE Folder_Template_Set__c = :folderTemplateSetId WITH SECURITY_ENFORCED ORDER BY Name ASC];
        }

        if (folders.isEmpty()) {
            return new List<TreeNode>();
        }

        // Build parent-to-children map
        Map<Id, List<Template_Folder__c>> parentToChildren = new Map<Id, List<Template_Folder__c>>();
        List<Template_Folder__c> rootFolders = new List<Template_Folder__c>();

        for (Template_Folder__c folder : folders) {
            if (folder.Parent_Template_Folder__c == null) {
                rootFolders.add(folder);
            } else {
                if (!parentToChildren.containsKey(folder.Parent_Template_Folder__c)) {
                    parentToChildren.put(folder.Parent_Template_Folder__c, new List<Template_Folder__c>());
                }
                parentToChildren.get(folder.Parent_Template_Folder__c).add(folder);
            }
        }

        // Sort root folders
        rootFolders.sort();

        // Flatten tree with levels
        List<TreeNode> result = new List<TreeNode>();
        for (Template_Folder__c rootFolder : rootFolders) {
            addFolderAndChildren(result, rootFolder, parentToChildren, 0);
        }

        return result;
    }

    /**
     * Creates a new template folder
     * @param name The folder name
     * @param folderTemplateSetId The parent Folder_Template_Set__c Id
     * @param parentFolderId Optional parent Template_Folder__c Id for nesting
     * @return OperationResult with success status and created record info
     */
    @AuraEnabled
    public static OperationResult createTemplateFolder(String name, String folderTemplateSetId, String parentFolderId) {
        if (String.isBlank(name)) {
            return new OperationResult(false, 'Folder name is required.');
        }

        if (String.isBlank(folderTemplateSetId)) {
            return new OperationResult(false, 'Folder Template Set is required.');
        }

        String trimmedName = name.trim();
        if (trimmedName.length() > 80) {
            return new OperationResult(false, 'Folder name must be 80 characters or less.');
        }

        // Check for duplicate name at same level
        Id parentId = String.isBlank(parentFolderId) ? null : Id.valueOf(parentFolderId);
        if (isDuplicateName(trimmedName, folderTemplateSetId, parentId, null)) {
            return new OperationResult(false, 'A folder with this name already exists at this level.');
        }

        try {
            Template_Folder__c newFolder = new Template_Folder__c(
                Name = trimmedName,
                Folder_Template_Set__c = folderTemplateSetId,
                Parent_Template_Folder__c = parentId
            );
            insert newFolder;
            return new OperationResult(true, newFolder.Id, newFolder.Name);
        } catch (Exception e) {
            return new OperationResult(false, 'Failed to create folder: ' + e.getMessage());
        }
    }

    /**
     * Renames a template folder
     * @param folderId The Template_Folder__c Id to rename
     * @param newName The new name
     * @return OperationResult with success status
     */
    @AuraEnabled
    public static OperationResult renameTemplateFolder(String folderId, String newName) {
        if (String.isBlank(folderId)) {
            return new OperationResult(false, 'Folder ID is required.');
        }

        if (String.isBlank(newName)) {
            return new OperationResult(false, 'Folder name is required.');
        }

        String trimmedName = newName.trim();
        if (trimmedName.length() > 80) {
            return new OperationResult(false, 'Folder name must be 80 characters or less.');
        }

        try {
            // Get current folder info
            Template_Folder__c folder;
            if (testBypassFLS) {
                folder = [SELECT Id, Name, Folder_Template_Set__c, Parent_Template_Folder__c FROM Template_Folder__c WHERE Id = :folderId LIMIT 1];
            } else {
                folder = [SELECT Id, Name, Folder_Template_Set__c, Parent_Template_Folder__c FROM Template_Folder__c WHERE Id = :folderId WITH SECURITY_ENFORCED LIMIT 1];
            }

            // Check for duplicate name at same level
            if (isDuplicateName(trimmedName, folder.Folder_Template_Set__c, folder.Parent_Template_Folder__c, folderId)) {
                return new OperationResult(false, 'A folder with this name already exists at this level.');
            }

            folder.Name = trimmedName;
            update folder;
            return new OperationResult(true, folder.Id, folder.Name);
        } catch (QueryException e) {
            return new OperationResult(false, 'Folder not found.');
        } catch (Exception e) {
            return new OperationResult(false, 'Failed to rename folder: ' + e.getMessage());
        }
    }

    /**
     * Moves a template folder to a new parent
     * @param folderId The Template_Folder__c Id to move
     * @param newParentFolderId The new parent folder Id (null for root level)
     * @return OperationResult with success status
     */
    @AuraEnabled
    public static OperationResult moveTemplateFolder(String folderId, String newParentFolderId) {
        if (String.isBlank(folderId)) {
            return new OperationResult(false, 'Folder ID is required.');
        }

        Id newParentId = String.isBlank(newParentFolderId) ? null : Id.valueOf(newParentFolderId);

        // Cannot move to self
        if (newParentId != null && folderId == newParentFolderId) {
            return new OperationResult(false, 'Cannot move a folder into itself.');
        }

        try {
            // Get current folder info
            Template_Folder__c folder;
            if (testBypassFLS) {
                folder = [SELECT Id, Name, Folder_Template_Set__c, Parent_Template_Folder__c FROM Template_Folder__c WHERE Id = :folderId LIMIT 1];
            } else {
                folder = [SELECT Id, Name, Folder_Template_Set__c, Parent_Template_Folder__c FROM Template_Folder__c WHERE Id = :folderId WITH SECURITY_ENFORCED LIMIT 1];
            }

            // Cannot move to current parent (no-op)
            if (folder.Parent_Template_Folder__c == newParentId) {
                return new OperationResult(true, folder.Id, folder.Name);
            }

            // Cannot move to a descendant
            if (newParentId != null && isDescendant(newParentId, folderId)) {
                return new OperationResult(false, 'Cannot move a folder into one of its subfolders.');
            }

            // Check for duplicate name at new level
            if (isDuplicateName(folder.Name, folder.Folder_Template_Set__c, newParentId, folderId)) {
                return new OperationResult(false, 'A folder with this name already exists at the destination level.');
            }

            folder.Parent_Template_Folder__c = newParentId;
            update folder;
            return new OperationResult(true, folder.Id, folder.Name);
        } catch (QueryException e) {
            return new OperationResult(false, 'Folder not found.');
        } catch (Exception e) {
            return new OperationResult(false, 'Failed to move folder: ' + e.getMessage());
        }
    }

    /**
     * Gets the count of child folders (descendants) for delete confirmation
     * @param folderId The Template_Folder__c Id
     * @return DeleteResult with childCount populated
     */
    @AuraEnabled
    public static DeleteResult getChildCount(String folderId) {
        if (String.isBlank(folderId)) {
            DeleteResult result = new DeleteResult(false, 'Folder ID is required.');
            return result;
        }

        try {
            Integer count = countAllDescendants(folderId);
            DeleteResult result = new DeleteResult(true, 0);
            result.childCount = count;
            return result;
        } catch (Exception e) {
            return new DeleteResult(false, 'Failed to get child count: ' + e.getMessage());
        }
    }

    /**
     * Deletes a template folder and all its descendants
     * @param folderId The Template_Folder__c Id to delete
     * @return DeleteResult with success status and deleted count
     */
    @AuraEnabled
    public static DeleteResult deleteTemplateFolder(String folderId) {
        if (String.isBlank(folderId)) {
            return new DeleteResult(false, 'Folder ID is required.');
        }

        try {
            // Get all descendant IDs (including the folder itself)
            Set<Id> idsToDelete = getAllDescendantIds(folderId);
            idsToDelete.add(Id.valueOf(folderId));

            // Delete all folders
            List<Template_Folder__c> foldersToDelete;
            if (testBypassFLS) {
                foldersToDelete = [SELECT Id FROM Template_Folder__c WHERE Id IN :idsToDelete];
            } else {
                foldersToDelete = [SELECT Id FROM Template_Folder__c WHERE Id IN :idsToDelete WITH SECURITY_ENFORCED];
            }

            Integer deleteCount = foldersToDelete.size();
            delete foldersToDelete;

            return new DeleteResult(true, deleteCount);
        } catch (Exception e) {
            return new DeleteResult(false, 'Failed to delete folder: ' + e.getMessage());
        }
    }

    /**
     * Gets folders that are valid move targets (excludes self and descendants)
     * @param folderId The folder being moved
     * @param folderTemplateSetId The Folder_Template_Set__c Id
     * @return List of TreeNode objects representing valid destinations
     */
    @AuraEnabled
    public static List<TreeNode> getMoveTargets(String folderId, String folderTemplateSetId) {
        if (String.isBlank(folderTemplateSetId)) {
            return new List<TreeNode>();
        }

        // Get all folders
        List<TreeNode> allFolders = getTemplateFolders(folderTemplateSetId);

        if (String.isBlank(folderId)) {
            return allFolders;
        }

        // Get IDs to exclude (self and descendants)
        Set<Id> excludeIds = getAllDescendantIds(folderId);
        excludeIds.add(Id.valueOf(folderId));

        // Filter out excluded folders
        List<TreeNode> validTargets = new List<TreeNode>();
        for (TreeNode node : allFolders) {
            if (!excludeIds.contains(node.recordId)) {
                validTargets.add(node);
            }
        }

        return validTargets;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // PRIVATE HELPER METHODS
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Recursively adds a folder and its children to the result list
     */
    private static void addFolderAndChildren(
        List<TreeNode> result,
        Template_Folder__c folder,
        Map<Id, List<Template_Folder__c>> parentToChildren,
        Integer level
    ) {
        List<Template_Folder__c> children = parentToChildren.get(folder.Id);
        Integer childCount = children != null ? children.size() : 0;

        TreeNode node = new TreeNode();
        node.key = folder.Id;
        node.label = folder.Name;
        node.recordId = folder.Id;
        node.parentFolderId = folder.Parent_Template_Folder__c;
        node.level = level;
        node.childCount = childCount;
        node.hasChildren = childCount > 0;

        result.add(node);

        // Recursively add children
        if (children != null && !children.isEmpty()) {
            children.sort();
            for (Template_Folder__c child : children) {
                addFolderAndChildren(result, child, parentToChildren, level + 1);
            }
        }
    }

    /**
     * Checks if a folder name already exists at the same level
     */
    private static Boolean isDuplicateName(String name, String setId, Id parentId, String excludeFolderId) {
        String query = 'SELECT Id FROM Template_Folder__c WHERE Folder_Template_Set__c = :setId AND Name = :name';

        if (parentId != null) {
            query += ' AND Parent_Template_Folder__c = :parentId';
        } else {
            query += ' AND Parent_Template_Folder__c = null';
        }

        if (String.isNotBlank(excludeFolderId)) {
            query += ' AND Id != :excludeFolderId';
        }

        query += (testBypassFLS ? '' : ' WITH SECURITY_ENFORCED') + ' LIMIT 1';

        List<Template_Folder__c> existing = Database.query(query);
        return !existing.isEmpty();
    }

    /**
     * Checks if potentialDescendant is a descendant of ancestorId
     */
    private static Boolean isDescendant(Id potentialDescendant, String ancestorId) {
        Set<Id> descendantIds = getAllDescendantIds(ancestorId);
        return descendantIds.contains(potentialDescendant);
    }

    /**
     * Gets all descendant folder IDs (not including the folder itself)
     */
    private static Set<Id> getAllDescendantIds(String folderId) {
        Set<Id> descendants = new Set<Id>();
        Set<Id> currentLevel = new Set<Id>{ Id.valueOf(folderId) };

        while (!currentLevel.isEmpty()) {
            List<Template_Folder__c> children;
            if (testBypassFLS) {
                children = [SELECT Id FROM Template_Folder__c WHERE Parent_Template_Folder__c IN :currentLevel];
            } else {
                children = [SELECT Id FROM Template_Folder__c WHERE Parent_Template_Folder__c IN :currentLevel WITH SECURITY_ENFORCED];
            }

            currentLevel = new Set<Id>();
            for (Template_Folder__c child : children) {
                descendants.add(child.Id);
                currentLevel.add(child.Id);
            }
        }

        return descendants;
    }

    /**
     * Counts all descendants of a folder
     */
    private static Integer countAllDescendants(String folderId) {
        return getAllDescendantIds(folderId).size();
    }
}
