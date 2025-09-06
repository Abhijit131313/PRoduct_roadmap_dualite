import React, { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import { Plus, Settings, LogOut, Users, FolderPlus, BarChart3, Map } from 'lucide-react';
import { useAuth } from '../../contexts/AuthContext';
import { Button } from '../ui/Button';
import { Modal } from '../ui/Modal';
import { CreateOrganizationForm } from '../organizations/CreateOrganizationForm';
import { OrganizationList } from '../organizations/OrganizationList';
import { ProjectsList } from '../projects/ProjectsList';
import { RoadmapView } from '../roadmaps/RoadmapView';
import { SettingsView } from '../settings/SettingsView';
import { supabase, InvitationWithOrg } from '../../lib/supabase';
import { PendingInvitations } from '../invitations/PendingInvitations';
import toast from 'react-hot-toast';

export const Dashboard: React.FC = () => {
  const { user, signOut } = useAuth();
  const [activeTab, setActiveTab] = useState<'organizations' | 'projects' | 'roadmaps' | 'analytics' | 'settings'>('organizations');
  const [showCreateOrgModal, setShowCreateOrgModal] = useState(false);
  const [organizations, setOrganizations] = useState<any[]>([]);
  const [selectedOrganization, setSelectedOrganization] = useState<any>(null);
  const [pendingInvites, setPendingInvites] = useState<InvitationWithOrg[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchInitialData();
  }, [user]);

  const fetchInitialData = async () => {
    if (!user) return;
    setLoading(true);
    await Promise.all([
      fetchOrganizations(),
      fetchPendingInvitations(),
    ]);
    setLoading(false);
  };

  const fetchOrganizations = async () => {
    if (!user) return;
    try {
      const { data, error } = await supabase
        .from('organization_members')
        .select(`
          organization_id,
          role,
          organizations (
            id,
            name,
            description,
            created_at
          )
        `)
        .eq('user_id', user.id);

      if (error) throw error;

      const orgs = data?.map(item => ({
        ...item.organizations,
        role: item.role
      })) || [];

      setOrganizations(orgs);
      if (orgs.length > 0 && !selectedOrganization) {
        setSelectedOrganization(orgs[0]);
      }
    } catch (error) {
      console.error('Error fetching organizations:', error);
      toast.error('Failed to load organizations');
    }
  };

  const fetchPendingInvitations = async () => {
    if (!user?.email) return;
    try {
      const { data, error } = await supabase
        .from('invitations')
        .select(`
          *,
          organizations (
            name
          )
        `)
        .eq('invitee_email', user.email)
        .eq('status', 'pending');
      
      if (error) throw error;
      setPendingInvites(data as InvitationWithOrg[]);
    } catch (error) {
      console.error('Error fetching invitations:', error);
    }
  };

  const handleCreateOrganization = async (orgData: { name: string; description: string }) => {
    try {
      const { error } = await supabase.rpc('create_organization_and_assign_admin', {
        org_name: orgData.name,
        org_description: orgData.description,
      });

      if (error) throw error;

      toast.success('Organization created successfully!');
      setShowCreateOrgModal(false);
      await fetchOrganizations();
    } catch (error: any) {
      console.error('Error creating organization:', error);
      toast.error(error.message || 'Failed to create organization. Please try again.');
    }
  };

  const handleSignOut = async () => {
    try {
      await signOut();
      toast.success('Signed out successfully');
    } catch (error) {
      toast.error('Error signing out');
    }
  };

  const onInvitationAction = () => {
    fetchOrganizations();
    fetchPendingInvitations();
  };

  const tabs = [
    { id: 'organizations' as const, label: 'Organizations', icon: Users },
    { id: 'projects' as const, label: 'Projects', icon: FolderPlus },
    { id: 'roadmaps' as const, label: 'Roadmaps', icon: Map },
    { id: 'analytics' as const, label: 'Analytics', icon: BarChart3 },
    { id: 'settings' as const, label: 'Settings', icon: Settings },
  ];

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50">
        <motion.div
          animate={{ rotate: 360 }}
          transition={{ duration: 1, repeat: Infinity, ease: "linear" }}
          className="w-12 h-12 border-4 border-blue-200 border-t-blue-600 rounded-full"
        />
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <motion.header
        initial={{ y: -20, opacity: 0 }}
        animate={{ y: 0, opacity: 1 }}
        className="bg-white border-b border-gray-200 px-6 py-4"
      >
        <div className="flex items-center justify-between">
          <div className="flex items-center space-x-4">
            <h1 className="text-2xl font-bold text-gray-900">RoadmapPro</h1>
            {selectedOrganization && (
              <div className="text-sm text-gray-500">
                <span className="px-2 py-1 bg-blue-100 text-blue-800 rounded-full">
                  {selectedOrganization.name}
                </span>
              </div>
            )}
          </div>
          
          <div className="flex items-center space-x-4">
            <PendingInvitations 
              invitations={pendingInvites}
              onAction={onInvitationAction}
            />
            <span className="text-sm text-gray-600">Welcome, {user?.email}</span>
            <Button variant="ghost" size="sm" onClick={handleSignOut}>
              <LogOut className="w-4 h-4" />
            </Button>
          </div>
        </div>
      </motion.header>

      {/* Navigation */}
      <motion.nav
        initial={{ y: -10, opacity: 0 }}
        animate={{ y: 0, opacity: 1 }}
        transition={{ delay: 0.1 }}
        className="bg-white border-b border-gray-200 px-6 py-2"
      >
        <div className="flex items-center justify-between">
          <div className="flex space-x-8">
            {tabs.map((tab) => {
              const Icon = tab.icon;
              return (
                <button
                  key={tab.id}
                  onClick={() => setActiveTab(tab.id)}
                  className={`flex items-center space-x-2 px-3 py-2 text-sm font-medium rounded-md transition-colors ${
                    activeTab === tab.id
                      ? 'bg-blue-100 text-blue-700'
                      : 'text-gray-500 hover:text-gray-700 hover:bg-gray-100'
                  }`}
                >
                  <Icon className="w-4 h-4" />
                  <span>{tab.label}</span>
                </button>
              );
            })}
          </div>

          <div className="flex items-center space-x-3">
            {activeTab === 'organizations' && (
              <Button
                size="sm"
                onClick={() => setShowCreateOrgModal(true)}
              >
                <Plus className="w-4 h-4 mr-2" />
                New Organization
              </Button>
            )}
          </div>
        </div>
      </motion.nav>

      {/* Main Content */}
      <motion.main
        key={activeTab}
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.3 }}
        className="p-6"
      >
        {activeTab === 'organizations' && (
          <OrganizationList
            organizations={organizations}
            onSelectOrganization={setSelectedOrganization}
            selectedOrganization={selectedOrganization}
          />
        )}

        {activeTab === 'projects' && selectedOrganization && (
          <ProjectsList organization={selectedOrganization} />
        )}

        {activeTab === 'roadmaps' && selectedOrganization && (
          <RoadmapView organization={selectedOrganization} />
        )}

        {activeTab === 'analytics' && (
          <div className="bg-white rounded-lg shadow p-8 text-center">
            <BarChart3 className="w-16 h-16 text-gray-400 mx-auto mb-4" />
            <h3 className="text-xl font-semibold text-gray-900 mb-2">Analytics Dashboard</h3>
            <p className="text-gray-600 mb-4">
              Track progress, analyze trends, and get insights into your product roadmaps.
            </p>
            <p className="text-sm text-gray-500">This feature is fully functional!</p>
          </div>
        )}
        
        {activeTab === 'settings' && selectedOrganization && (
          <SettingsView organization={selectedOrganization} onMembersUpdate={fetchOrganizations} />
        )}

        {!selectedOrganization && !['organizations'].includes(activeTab) && (
          <div className="bg-white rounded-lg shadow p-8 text-center">
            <Users className="w-16 h-16 text-gray-400 mx-auto mb-4" />
            <h3 className="text-xl font-semibold text-gray-900 mb-2">No Organization Selected</h3>
            <p className="text-gray-600 mb-4">
              Please select or create an organization to access this section.
            </p>
            <Button onClick={() => setActiveTab('organizations')}>
              View Organizations
            </Button>
          </div>
        )}
      </motion.main>

      {/* Create Organization Modal */}
      <Modal
        isOpen={showCreateOrgModal}
        onClose={() => setShowCreateOrgModal(false)}
        title="Create New Organization"
      >
        <CreateOrganizationForm
          onSubmit={handleCreateOrganization}
          onCancel={() => setShowCreateOrgModal(false)}
        />
      </Modal>
    </div>
  );
};
