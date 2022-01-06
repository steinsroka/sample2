import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:sample2/record.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({Key? key}) : super(key: key);

  @override
  _ResultScreenState createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('aa')
      ),
      body: StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
        stream: FirebaseFirestore.instance.collection('record').doc('first').collection('data').snapshots(),
        //stream:
        builder: (context, snapshot) {
          var d = snapshot.requireData;
          if(snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
          if(!snapshot.hasData) return const Center(child:CircularProgressIndicator());
          return ListView.builder(
              itemCount: snapshot.requireData.size,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(d.docs[index].data().toString())
                );
              }
          );
        }
      ),
    );
  }
}


