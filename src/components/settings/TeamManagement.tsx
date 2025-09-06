import React, { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import { Plus, Trash2, User, Mail, Clock } from 'lucide-react';
import { Button } from '../ui/Button';
import { Modal } from '../ui/Modal';
import { InviteMemberForm } from './InviteMemberForm';
import { supabase, OrganizationMemberWithProfile, Database } from '../../lib/supabase';
import { useAuth } from '../../contexts/AuthContext';
import toast from 'react-hot-toast';

interface TeamManagementProps {
  organization: any;
  onMembersUpdate: () => void;
}

type PendingInvite = Database['public']['Tables']['invitations']['Row'];

const roleColors = {
  admin: 'bg-purple-100 text-purple-800',
  editor: 'bg-green-100 text-green-800',
  viewer: 'bg-gray-100 text-gray-800',
};

export const TeamManagement: React.FC<TeamManagementProps> = ({ organization, onMembersUpdate }) => {
  const { user } = useAuth();
  const [members, setMembers] = useState<OrganizationMemberWithProfile[]>([]);
  const [pendingInvites, setPendingInvites] = useState<PendingInvite[]>([]);
  const [loading, setLoading] = useState(true);
  const [showInviteModal, setShowInviteModal] = useState(false);

  const currentUserRole = organization.role;

  useEffect(() => {
    fetchData();
  }, [organization]);

  const fetchData = async () => {
    setLoading(true);
    await Promise.all([fetchMembers(), fetchPendingInvites()]);
    setLoading(false);
  };

  const fetchMembers = async () => {
    try {
      const { data, error } = await supabase
        .from('organization_members')
        .select(`
          *,
          profiles (
            full_name,
            email,
            avatar_url
          )
        `)
        .eq('organization_id', organization.id);

      if (error) throw error;
      setMembers(data as OrganizationMemberWithProfile[]);
    } catch (error: any) {
      console.error('Error fetching members:', error);
      toast.error(error.message || 'Failed to load team members.');
    }
  };
  
  const fetchPendingInvites = async () => {
    try {
      const { data, error } = await supabase
        .from('invitations')
        .select('*')
        .eq('organization_id', organization.id)
        .eq('status', 'pending');

      if (error) throw error;
      setPendingInvites(data);
    } catch (error: any) {
      console.error('Error fetching pending invites:', error);
    }
  };

  const handleInviteMember = async (inviteData: { email: string; role: 'admin' | 'editor' | 'viewer' }) => {
    try {
      const { error } = await supabase.rpc('invite_organization_member', {
        org_id: organization.id,
        invitee_email: inviteData.email,
        invitee_role: inviteData.role,
      });

      if (error) throw error;

      toast.success(`Invitation sent to ${inviteData.email}`);
      setShowInviteModal(false);
      fetchPendingInvites();
    } catch (error: any) {
      console.error('Error inviting member:', error);
      toast.error(error.message || 'Failed to invite member.');
    }
  };

  const handleUpdateRole = async (memberId: string, newRole: 'admin' | 'editor' | 'viewer') => {
    try {
      const { error } = await supabase.rpc('update_organization_member_role', {
        member_id: memberId,
        new_role: newRole,
      });
      if (error) throw error;
      toast.success('Member role updated.');
      fetchMembers();
    } catch (error: any) {
      console.error('Error updating role:', error);
      toast.error(error.message || 'Failed to update role.');
    }
  };

  const handleRemoveMember = async (member: OrganizationMemberWithProfile) => {
    if (!window.confirm(`Are you sure you want to remove ${member.profiles?.full_name || member.profiles?.email}?`)) {
      return;
    }
    try {
      const { error } = await supabase.rpc('remove_organization_member', {
        member_id: member.id,
      });
      if (error) throw error;
      toast.success('Member removed from organization.');
      fetchMembers();
    } catch (error: any) {
      console.error('Error removing member:', error);
      toast.error(error.message || 'Failed to remove member.');
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center py-12">
        <motion.div
          animate={{ rotate: 360 }}
          transition={{ duration: 1, repeat: Infinity, ease: 'linear' }}
          className="w-8 h-8 border-2 border-blue-200 border-t-blue-600 rounded-full"
        />
      </div>
    );
  }

  return (
    <div className="bg-white rounded-lg shadow p-6">
      <div className="flex items-center justify-between mb-4">
        <div>
          <h3 className="text-xl font-bold text-gray-900">Team Members</h3>
          <p className="text-gray-600">Manage who has access to this organization.</p>
        </div>
        {currentUserRole === 'admin' && (
          <Button onClick={() => setShowInviteModal(true)}>
            <Plus className="w-4 h-4 mr-2" />
            Invite Member
          </Button>
        )}
      </div>

      <div className="flow-root">
        <ul role="list" className="divide-y divide-gray-200">
          {members.map((member) => (
            <li key={member.id} className="py-4 flex items-center justify-between">
              <div className="flex items-center space-x-4">
                <div className="flex-shrink-0">
                  {member.profiles?.avatar_url ? (
                    <img className="h-10 w-10 rounded-full" src={member.profiles.avatar_url} alt="" />
                  ) : (
                    <div className="h-10 w-10 rounded-full bg-gray-200 flex items-center justify-center">
                      <User className="w-6 h-6 text-gray-500" />
                    </div>
                  )}
                </div>
                <div>
                  <p className="text-sm font-medium text-gray-900 truncate">{member.profiles?.full_name || 'No Name'}</p>
                  <p className="text-sm text-gray-500 truncate">{member.profiles?.email}</p>
                </div>
              </div>
              <div className="flex items-center space-x-4">
                {currentUserRole === 'admin' && member.user_id !== user?.id ? (
                  <select
                    value={member.role}
                    onChange={(e) => handleUpdateRole(member.id, e.target.value as any)}
                    className={`text-sm font-medium border-none rounded-md focus:ring-2 focus:ring-blue-500 ${roleColors[member.role]}`}
                  >
                    <option value="admin">Admin</option>
                    <option value="editor">Editor</option>
                    <option value="viewer">Viewer</option>
                  </select>
                ) : (
                  <span className={`px-3 py-1 text-sm font-medium rounded-md ${roleColors[member.role]}`}>
                    {member.role.charAt(0).toUpperCase() + member.role.slice(1)}
                  </span>
                )}
                
                {currentUserRole === 'admin' && member.user_id !== user?.id && (
                  <Button variant="ghost" size="sm" onClick={() => handleRemoveMember(member)}>
                    <Trash2 className="w-4 h-4 text-red-500" />
                  </Button>
                )}
              </div>
            </li>
          ))}
        </ul>
      </div>

      {pendingInvites.length > 0 && (
        <div className="mt-8 border-t pt-6">
          <h4 className="text-lg font-semibold text-gray-800 mb-4">Pending Invitations</h4>
          <ul role="list" className="divide-y divide-gray-200">
            {pendingInvites.map(invite => (
              <li key={invite.id} className="py-3 flex items-center justify-between">
                <div className="flex items-center space-x-3">
                  <div className="h-10 w-10 rounded-full bg-gray-100 flex items-center justify-center">
                    <Mail className="w-5 h-5 text-gray-500" />
                  </div>
                  <div>
                    <p className="text-sm font-medium text-gray-900">{invite.invitee_email}</p>
                    <p className="text-sm text-gray-500">Invited as {invite.role}</p>
                  </div>
                </div>
                <div className="flex items-center space-x-2 text-sm text-gray-500">
                  <Clock className="w-4 h-4" />
                  <span>Pending</span>
                </div>
              </li>
            ))}
          </ul>
        </div>
      )}

      <Modal
        isOpen={showInviteModal}
        onClose={() => setShowInviteModal(false)}
        title="Invite New Member"
      >
        <InviteMemberForm
          onSubmit={handleInviteMember}
          onCancel={() => setShowInviteModal(false)}
        />
      </Modal>
    </div>
  );
};
