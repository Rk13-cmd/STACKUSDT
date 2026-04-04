import { db } from './supabase';

export class MissionService {
  async getAllMissions(period?: string): Promise<any[]> {
    const { supabase } = await import('./supabase');
    let query = supabase.from('missions').select('*').eq('is_active', true).order('reward_usdt', { ascending: true });
    if (period) query = query.eq('period', period);
    const { data, error } = await query;
    if (error) throw new Error(error.message);
    return data || [];
  }

  async getUserMissionProgress(userId: string, period: string = 'daily'): Promise<any[]> {
    const { supabase } = await import('./supabase');

    const periodStart = this.getPeriodStart(period);

    const { data: missions } = await supabase
      .from('missions')
      .select('*')
      .eq('is_active', true)
      .eq('period', period);

    if (!missions || missions.length === 0) return [];

    const { data: progress } = await supabase
      .from('user_mission_progress')
      .select('*')
      .eq('user_id', userId)
      .eq('period_start', periodStart);

    const progressMap: Record<string, any> = {};
    progress?.forEach((p: any) => { progressMap[p.mission_id] = p; });

    return missions.map((m: any) => ({
      ...m,
      progress: progressMap[m.id]?.progress_value || 0,
      is_completed: progressMap[m.id]?.is_completed || false,
      is_claimed: progressMap[m.id]?.is_claimed || false,
      period_start: periodStart,
    }));
  }

  async updateMissionProgress(userId: string, type: string, value: number): Promise<void> {
    const { supabase } = await import('./supabase');

    const periods = ['daily', 'weekly', 'monthly'];

    for (const period of periods) {
      const { data: missions } = await supabase
        .from('missions')
        .select('id, requirement_value')
        .eq('is_active', true)
        .eq('type', type)
        .eq('period', period);

      if (!missions || missions.length === 0) continue;

      const periodStart = this.getPeriodStart(period);

      for (const mission of missions) {
        const { data: existing } = await supabase
          .from('user_mission_progress')
          .select('*')
          .eq('user_id', userId)
          .eq('mission_id', mission.id)
          .eq('period_start', periodStart)
          .single();

        if (existing) {
          if (existing.is_completed) continue;

          const newProgress = Math.min((existing.progress_value || 0) + value, (mission as any).requirement_value);
          const isCompleted = newProgress >= (mission as any).requirement_value;

          await supabase
            .from('user_mission_progress')
            .update({
              progress_value: newProgress,
              is_completed: isCompleted,
              updated_at: new Date().toISOString(),
            })
            .eq('id', existing.id);

          if (isCompleted) {
            await db.createNotification(
              userId,
              'mission_completed',
              'Mission Complete!',
              'You completed: ' + (mission as any).name + '. Claim your reward of $' + (mission as any).reward_usdt + ' USDT!'
            );
          }
        } else {
          const newProgress = Math.min(value, (mission as any).requirement_value);
          const isCompleted = newProgress >= (mission as any).requirement_value;

          await supabase.from('user_mission_progress').insert({
            user_id: userId,
            mission_id: mission.id,
            progress_value: newProgress,
            is_completed: isCompleted,
            is_claimed: false,
            period_start: periodStart,
          });

          if (isCompleted) {
            await db.createNotification(
              userId,
              'mission_completed',
              'Mission Complete!',
              'You completed: ' + (mission as any).name + '. Claim your reward of $' + (mission as any).reward_usdt + ' USDT!'
            );
          }
        }
      }
    }
  }

  async claimMissionReward(userId: string, missionId: string): Promise<any> {
    const { supabase } = await import('./supabase');

    const { data: mission } = await supabase
      .from('missions')
      .select('*')
      .eq('id', missionId)
      .single();

    if (!mission) throw new Error('Mission not found');

    const periodStart = this.getPeriodStart(mission.period);

    const { data: progress, error: fetchError } = await supabase
      .from('user_mission_progress')
      .select('*')
      .eq('user_id', userId)
      .eq('mission_id', missionId)
      .eq('period_start', periodStart)
      .single();

    if (fetchError || !progress) throw new Error('Mission progress not found');
    if (!progress.is_completed) throw new Error('Mission not completed yet');
    if (progress.is_claimed) throw new Error('Reward already claimed');

    await db.updateUserBalance(userId, mission.reward_usdt, 'add');

    if (mission.reward_xp > 0) {
      await db.updateMiningXP(userId, mission.reward_xp);
    }

    await supabase
      .from('user_mission_progress')
      .update({ is_claimed: true, updated_at: new Date().toISOString() })
      .eq('id', progress.id);

    return {
      mission: mission.name,
      reward_usdt: mission.reward_usdt,
      reward_xp: mission.reward_xp,
    };
  }

  async createMission(data: {
    name: string;
    type: string;
    description?: string;
    requirement_value: number;
    reward_usdt: number;
    reward_xp?: number;
    period: string;
  }): Promise<any> {
    const { supabase } = await import('./supabase');
    const { data: result, error } = await supabase
      .from('missions')
      .insert({
        name: data.name,
        type: data.type,
        description: data.description,
        requirement_value: data.requirement_value,
        reward_usdt: data.reward_usdt,
        reward_xp: data.reward_xp || 0,
        period: data.period,
        is_active: true,
      })
      .select()
      .single();

    if (error) throw new Error(error.message);
    return result;
  }

  async toggleMission(missionId: string, isActive: boolean): Promise<void> {
    const { supabase } = await import('./supabase');
    const { error } = await supabase
      .from('missions')
      .update({ is_active: isActive })
      .eq('id', missionId);
    if (error) throw new Error(error.message);
  }

  private getPeriodStart(period: string): string {
    const now = new Date();
    switch (period) {
      case 'daily':
        return new Date(now.getFullYear(), now.getMonth(), now.getDate()).toISOString().split('T')[0];
      case 'weekly': {
        const dayOfWeek = now.getDay();
        const monday = new Date(now);
        monday.setDate(now.getDate() - (dayOfWeek === 0 ? 6 : dayOfWeek - 1));
        return monday.toISOString().split('T')[0];
      }
      case 'monthly':
        return new Date(now.getFullYear(), now.getMonth(), 1).toISOString().split('T')[0];
      default:
        return now.toISOString().split('T')[0];
    }
  }

  async getMissionStats(): Promise<any> {
    const { supabase } = await import('./supabase');

    const { data: allProgress } = await supabase
      .from('user_mission_progress')
      .select('is_completed, is_claimed, mission_id');

    const { data: missions } = await supabase.from('missions').select('id, name, type, period');

    const totalCompletions = allProgress?.filter((p: any) => p.is_completed).length || 0;
    const totalClaims = allProgress?.filter((p: any) => p.is_claimed).length || 0;
    const completionRate = allProgress && allProgress.length > 0
      ? (totalCompletions / allProgress.length) * 100
      : 0;

    return {
      total_completions: totalCompletions,
      total_claims: totalClaims,
      completion_rate: Math.round(completionRate * 100) / 100,
      missions_count: missions?.length || 0,
    };
  }
}

export const missionService = new MissionService();
