import React, { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Bell, Check, X } from 'lucide-react';
import { Button } from '../ui/Button';
import { supabase, InvitationWithOrg } from '../../lib/supabase';
import toast from 'react-hot-toast';

interface PendingInvitationsProps {
  invitations: InvitationWithOrg[];
  onAction: () => void;
}

export const PendingInvitations: React.FC<PendingInvitationsProps> = ({ invitations, onAction }) => {
  const [isOpen, setIsOpen] = useState(false);
  const [loadingInvite, setLoadingInvite] = useState<string | null>(null);

  const handleAction = async (action: 'accept' | 'decline', invitationId: string) => {
    setLoadingInvite(invitationId);
    try {
      const rpcName = action === 'accept' ? 'accept_invitation' : 'decline_invitation';
      const { error } = await supabase.rpc(rpcName, { invitation_id: invitationId });
      
      if (error) throw error;
      
      toast.success(`Invitation ${action}ed successfully!`);
      onAction();
    } catch (error: any) {
      toast.error(error.message || `Failed to ${action} invitation.`);
    } finally {
      setLoadingInvite(null);
      setIsOpen(false);
    }
  };

  if (invitations.length === 0) {
    return null;
  }

  return (
    <div className="relative">
      <Button variant="ghost" size="sm" onClick={() => setIsOpen(!isOpen)}>
        <Bell className="w-5 h-5" />
        <div className="absolute top-0 right-0 w-3 h-3 bg-red-500 rounded-full border-2 border-white" />
      </Button>

      <AnimatePresence>
        {isOpen && (
          <motion.div
            initial={{ opacity: 0, y: -10 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -10 }}
            className="absolute right-0 mt-2 w-80 bg-white rounded-lg shadow-lg border z-10"
          >
            <div className="p-4 border-b">
              <h4 className="font-semibold text-gray-800">Pending Invitations</h4>
            </div>
            <ul className="py-2 max-h-64 overflow-y-auto">
              {invitations.map(invite => (
                <li key={invite.id} className="px-4 py-2 hover:bg-gray-50">
                  <p className="text-sm text-gray-700">
                    You've been invited to join{' '}
                    <span className="font-semibold">{invite.organizations?.name || 'an organization'}</span>
                    {' '}as a <span className="font-semibold">{invite.role}</span>.
                  </p>
                  <div className="flex items-center justify-end space-x-2 mt-2">
                    <Button
                      size="sm"
                      variant="outline"
                      onClick={() => handleAction('decline', invite.id)}
                      loading={loadingInvite === invite.id}
                      disabled={!!loadingInvite}
                    >
                      <X className="w-4 h-4" />
                    </Button>
                    <Button
                      size="sm"
                      variant="primary"
                      onClick={() => handleAction('accept', invite.id)}
                      loading={loadingInvite === invite.id}
                      disabled={!!loadingInvite}
                    >
                      <Check className="w-4 h-4" />
                    </Button>
                  </div>
                </li>
              ))}
            </ul>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
};
