import React from 'react';
import { TeamManagement } from './TeamManagement';

interface SettingsViewProps {
  organization: any;
  onMembersUpdate: () => void;
}

export const SettingsView: React.FC<SettingsViewProps> = ({ organization, onMembersUpdate }) => {
  return (
    <div className="space-y-8">
      <div>
        <h2 className="text-2xl font-bold text-gray-900">Organization Settings</h2>
        <p className="text-gray-600">Manage your team and organization details.</p>
      </div>

      <TeamManagement organization={organization} onMembersUpdate={onMembersUpdate} />

      {/* Future settings panels can be added here */}
      {/* e.g., <BillingSettings />, <GeneralSettings /> */}
    </div>
  );
};
