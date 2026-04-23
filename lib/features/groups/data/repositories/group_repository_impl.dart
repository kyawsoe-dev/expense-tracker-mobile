import 'package:dio/dio.dart';
import '../../domain/entities/expense_group.dart';
import '../../domain/repositories/group_repository.dart';
import '../models/expense_group_model.dart';

class GroupRepositoryImpl implements GroupRepository {
  final Dio dio;

  GroupRepositoryImpl(this.dio);

  @override
  Future<void> createGroup(String name,
      {List<String> memberEmails = const []}) async {
    await dio.post('/groups', data: {
      'name': name.trim(),
      if (memberEmails.isNotEmpty) 'memberEmails': memberEmails,
    });
  }

  @override
  Future<List<ExpenseGroup>> getGroups() async {
    final response = await dio.get('/groups');
    final List<dynamic> data = response.data as List<dynamic>;
    return data
        .map((e) => ExpenseGroupModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<ExpenseGroup> getGroupDetail(String id) async {
    final response = await dio.get('/groups/$id');
    return ExpenseGroupModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<ExpenseGroup> addMember(String groupId, String email) async {
    final response = await dio.post('/groups/$groupId/members', data: {
      'email': email.trim(),
    });
    return ExpenseGroupModel.fromJson(response.data as Map<String, dynamic>);
  }
}
